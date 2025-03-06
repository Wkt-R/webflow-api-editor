class WebflowService
  BASE_URL = "https://api.webflow.com/v2"
  API_TOKEN = ENV["WEBFLOW_API_TOKEN"]
  COLLECTION_ID = ENV["WEBFLOW_COLLECTION_ID"]

  def self.get_custom_fields
    uri = URI("#{BASE_URL}/collections/#{COLLECTION_ID}/items")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{API_TOKEN}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      items = data["items"].map do |item|
        {
          id: item["id"],
          stanowisko: item["fieldData"]["stanowisko"],
          lokalizacja: item["fieldData"]["lokalizacja"],
          opis_stanowiska: item["fieldData"]["wymagania2"],
          aktywne: item["fieldData"]["aktywne-2"]
        }
      end
      items
    else
      { error: "Failed to fetch data from Webflow: #{response.body}" }
    end
  end

  def self.update_item(item_id, updated_data)
    uri = URI("#{BASE_URL}/collections/#{COLLECTION_ID}/items/#{item_id}")
    request = Net::HTTP::Patch.new(uri)
    request["Authorization"] = "Bearer #{API_TOKEN}"
    request["Content-Type"] = "application/json"

    request.body = {
      fieldData: {
        "stanowisko" => updated_data[:stanowisko],
        "lokalizacja" => updated_data[:lokalizacja],
        "wymagania2" => updated_data[:opis_stanowiska],
        "aktywne-2" => updated_data[:aktywne]
      }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      item_id = data["id"]
      publish_item(COLLECTION_ID, item_id)
      { success: true, item_id: item_id }
    else
      { success: false, error: response.body }
    end
  end

  def self.create_item(new_data)
    uri = URI("#{BASE_URL}/collections/#{COLLECTION_ID}/items")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{API_TOKEN}"
    request["Content-Type"] = "application/json"

    request.body = {
      "items" => [
        {
          "fieldData" => {
            "name" => new_data[:stanowisko],
            "stanowisko" => new_data[:stanowisko],
            "lokalizacja" => new_data[:lokalizacja],
            "wymagania2" => new_data[:opis_stanowiska],
            "aktywne-2" => new_data[:aktywne]
          }
        }
      ]
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      item_id = data["items"].first["id"]
      publish_item(COLLECTION_ID, item_id)
      { success: true, item_id: item_id }
    else
      { success: false, error: response.body }
    end
  end

  def self.publish_item(collection_id, item_id)
    uri = URI("https://api.webflow.com/v2/collections/#{collection_id}/items/publish")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{API_TOKEN}"
    request["Content-Type"] = "application/json"
    request.body = { "itemIds" => [ item_id ] }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      { success: true }
    else
      error_message = begin
                        JSON.parse(response.body)["msg"] || response.body
                      rescue
                        response.body
                      end
      Rails.logger.error("Publish failed: #{error_message}")
      { success: false, error: error_message }
    end
  end
end
