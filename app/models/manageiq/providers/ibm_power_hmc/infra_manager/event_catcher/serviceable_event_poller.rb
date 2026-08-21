require_relative '../utility/xml_to_json_transformer'

# Encapsulates the periodic polling of IBM HMC Serviceable Events.
#
# Called from Stream#poll on each loop iteration; responsible for:
#   1. Deciding whether the configured poll interval has elapsed.
#   2. Fetching raw XML from the HMC via +connection.fetch_serviceable_events_xml+.
#   3. Parsing each feed entry and persisting an EmsEvent record via EmsEvent.add_queue.
#
class ManageIQ::Providers::IbmPowerHmc::InfraManager::EventCatcher::ServiceableEventPoller
  POLL_INTERVAL = 600 # seconds between successive serviceable-event fetches

  def initialize(ems)
    @ems       = ems
    @last_poll = Time.now.utc.to_i - POLL_INTERVAL
  end

  # Poll serviceable events if the interval has elapsed.
  #
  # @param connection [IbmPowerHmc::Connection]  active HMC connection from Stream#poll
  def poll(connection)
    now = Time.now.utc.to_i
    return unless now >= @last_poll + POLL_INTERVAL

    @last_poll = now
    fetch_and_process(connection)
  end

  private

  def fetch_and_process(connection)
    sem_xml = connection.serviceable_events_search
    return if sem_xml.blank?

    feed = ManageIQ::Providers::IbmPowerHmc::InfraManager::XmlToJsonTransformer.transform(sem_xml)
    process_entries(feed)
  end

  def process_entries(feed)
    entries = feed.dig("feed", "entries") || []
    return if entries.empty?

    # ── ONE bulk SELECT for the entire batch ──────────────────────────────────
    # Fetch only the columns needed for change-detection — message and full_data.
    # Build a lightweight Hash keyed by prob_uuid (message) → full_data so that
    # each entry lookup is O(1) with no additional DB hits.
    #
    existing_map = EmsEvent
                   .where(:ems_id => @ems.id, :event_type => "ServiceableEvent", :source => "IBM_POWER_HMC")
                   .pluck(:message, :full_data)
                   .each_with_object({}) do |(msg, full_data), hash|
                     hash[msg] = full_data
                   end

    entries.each { |entry| upsert_entry(entry, existing_map) }
  end

  # Process a single feed entry using the pre-fetched lookup.
  # No DB reads happen here — all decisions are made from the in-memory lookup.
  def upsert_entry(entry, existing_map)
    sem       = entry.dig("content", "ServiceableEvent") || {}
    entry_id  = entry["id"]
    published = entry["published"]

    # ── Mapped columns ────────────────────────────────────────────────────────
    # message   → Problem UUID (unique identifier for the serviceable event)
    # host_name → Failing Console MTMS  (machtype-model*serial)
    # vm_name   → Partition Name
    prob_uuid    = extract_value(sem["problemUuid"])
    failing_mtms = build_failing_mtms(sem)
    lpar_name    = extract_value(sem["partitionName"])

    sem_data = {
      :problem_uuid         => prob_uuid,
      :problem_number       => sem.dig("problemNumber", "_value"),
      :problem_state        => sem.dig("problemState", "_value"),
      :event_severity       => sem.dig("eventSeverity", "_value"),
      :reference_code       => sem.dig("referenceCode", "_value"),
      :notification_type    => sem.dig("notificationType", "_value"),
      :symptom_string       => sem.dig("symptomString", "_value"),
      :short_description    => sem.dig("shortDescription", "_value"),
      :duplicate_count      => sem.dig("duplicateCount", "_value"),
      :platform_log_id      => sem.dig("platformLogId", "_value"),
      :failing_mtms         => failing_mtms,
      :partition_name       => lpar_name,
      :src_extension_data   => sem["srcExtnData"],
      :extended_error_files => sem.dig("extendedErrorData", "ExtendedFileData"),
      :service_history      => sem.dig("serviceHistoryData", "ServiceHistory")
    }

    event_hash = {
      :event_type => "ServiceableEvent",
      :source     => "IBM_POWER_HMC",
      :ems_ref    => entry_id,
      :timestamp  => published,
      :message    => prob_uuid,
      :host_name  => failing_mtms,
      :vm_name    => lpar_name,
      :full_data  => sem_data,
      :ems_id     => @ems.id
    }

    # O(1) hash lookup — no DB hit
    existing_full_data = existing_map[prob_uuid]

    # Always add a new record when there is no existing entry OR when the
    # event data has changed. Updating in-place is intentionally avoided so
    # that every state change is preserved as a separate EmsEvent row.
    if existing_full_data.nil? || existing_full_data != sem_data
      EmsEvent.add_queue('add', @ems.id, event_hash)
    end
  end

  # Extract the plain string value from a transformer node.
  # Plain leaf elements are already a String (or nil).
  def extract_value(node)
    node.kind_of?(Hash) ? node["_value"] : node
  end

  # Build the Failing Console MTMS string from the transformer-produced SEM hash.
  # The transformer converts the XML directly to nested string-keyed hashes, so
  # failingManagedSystemNode/managedTypeModelSerial/{MachineType,Model,SerialNumber}
  # are already present — we just concatenate them the same way the SDK does.
  # Returns nil when the node is absent entirely.
  def build_failing_mtms(sem)
    node     = sem.dig("failingManagedSystemNode", "managedTypeModelSerial") || {}
    machtype = extract_value(node["MachineType"])
    model    = extract_value(node["Model"])
    serial   = extract_value(node["SerialNumber"])
    return nil if machtype.nil? && model.nil? && serial.nil?

    "#{machtype}-#{model}*#{serial}"
  end
end
