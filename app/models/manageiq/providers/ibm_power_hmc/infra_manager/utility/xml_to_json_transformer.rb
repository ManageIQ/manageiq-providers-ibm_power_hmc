require "rexml/document"

# Transforms an IBM HMC Atom-feed XML string (as returned by the HMC REST API or
# embedded in an RTF log file) into a plain Ruby Hash that is JSON-serialisable.
#
# Usage
#   hash  = ManageIQ::Providers::IbmPowerHmc::InfraManager::XmlToJsonTransformer.transform(xml_string)
#   json  = JSON.generate(hash)
#
module ManageIQ::Providers::IbmPowerHmc::InfraManager::XmlToJsonTransformer
  # ── Public entry points ───────────────────────────────────────────────────

  # Transform a raw XML string into a JSON-serialisable Hash.
  #
  # @param xml_text [String]  well-formed XML (the full Atom feed as a String)
  # @return [Hash]            JSON-serialisable Hash
  def self.transform(xml_text)
    root = parse_xml(xml_text)
    build_hash(root)
  end

  # ── Private helpers ───────────────────────────────────────────────────────

  # Parse the XML string and return the root REXML::Element.
  # @raise [REXML::ParseException] on malformed XML
  private_class_method def self.parse_xml(xml_text)
    doc = REXML::Document.new(xml_text)
    doc.root
  end

  # Convert an REXML::Element recursively into a plain Ruby object.
  #
  # Rules (identical to the Python reference):
  #   - XML-namespace prefixes are stripped from tag names and attribute keys.
  #   - Attributes are stored under "_attr" (only when non-empty).
  #   - Multiple sibling elements with the same local tag become an Array.
  #   - A leaf element with no children and no attributes → its text (String) or nil.
  #
  # @param elem [REXML::Element]
  # @return [Hash]  { local_tag_name => value }
  private_class_method def self.elem_to_hash(elem)
    tag = strip_ns(elem.name)

    children = elem.elements.to_a
    text     = (elem.text || "").strip
    # REXML's to_hash returns REXML::Attribute objects; iterate to get plain Strings.
    attrs = {}
    elem.attributes.each { |name, val| attrs[strip_ns(name)] = val }
    attrs.reject! { |k, _v| k.start_with?("xmlns") }

    # ── Leaf node ──────────────────────────────────────────────────────────
    if children.empty?
      value =
        if attrs.any?
          {"_value" => text.empty? ? nil : text, "_attr" => attrs}
        else
          text.empty? ? nil : text
        end
      return {tag => value}
    end

    # ── Node with children ─────────────────────────────────────────────────
    child_hash = {}
    children.each do |child|
      child_result = elem_to_hash(child) # {child_tag => value}
      child_result.each do |k, v|
        if child_hash.key?(k)
          child_hash[k] = [child_hash[k]] unless child_hash[k].kind_of?(Array)
          child_hash[k] << v
        else
          child_hash[k] = v
        end
      end
    end

    child_hash["_attr"] = attrs if attrs.any?

    {tag => child_hash}
  end

  # Build the top-level { "feed" => … } hash from the <feed> root element.
  private_class_method def self.build_hash(root)
    feed_attrs = {}
    root.attributes.each { |name, val| feed_attrs[strip_ns(name)] = val }
    feed_attrs.reject! { |k, _v| k.start_with?("xmlns") }

    result = feed_attrs.any? ? {"_attr" => feed_attrs} : {}

    entries = []
    root.elements.each do |child|
      local = strip_ns(child.name)
      if local == "entry"
        entry = {}
        child.elements.each do |sub|
          sub_local = strip_ns(sub.name)
          entry[sub_local] = elem_to_hash(sub)[sub_local]
        end
        entries << entry
      else
        converted = elem_to_hash(child)
        result[local] = converted[local]
      end
    end

    result["entries"] = entries
    {"feed" => result}
  end

  # Strip XML namespace prefix: "{http://...}tag"  →  "tag"
  #                             "ns:tag"            →  "tag"
  private_class_method def self.strip_ns(name)
    name.to_s.sub(/\A\{[^}]+\}/, "").sub(/\A[^:]+:/, "")
  end
end
