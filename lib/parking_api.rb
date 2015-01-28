require 'open-uri'
require 'nokogiri'
require 'json'
require 'time'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

class ParkingApi
  def self.call(env)
    [200, {"Content-Type"=>"application/json; charset=utf-8", "Access-Control-Allow-Origin"=>"*"}, StringIO.new(self.get_parking_spaces)]
  end

  CACHE_MAX_AGE = 60
  @base_url = 'http://www5.stadt-muenster.de/parkhaeuser/'
  @geojson = JSON.parse(open(File.join(File.dirname(File.expand_path(__FILE__)), 'parking_spaces.json')).read)
  @geojson["features"].map! { |e| e.delete("geometry"); e }
  @cache = {
    fetch_time: 0
  }

  def self.get_parking_spaces
    unless Time.now.to_i - @cache[:fetch_time] < CACHE_MAX_AGE
      self.build_cache()
    end
    @cache["features"].map {|f| f.to_json}.join("\n")
  end

  def self.build_cache
    parking_spaces = @geojson["features"].clone

    doc = Nokogiri::HTML(open(@base_url))
    fetch_time = Time.now.to_i

    doc.css('area').each do |area|
      index = parking_spaces.index { |f| f["properties"]["name"] == area["alt"] }

      unless index == nil
        parking_spaces[index]["properties"].merge!({
          free: area['onclick'][/frei=[\d]+/].split('=')[1].to_i,
          total: area['onclick'][/gesamt=[\d]+/].split('=')[1].to_i,
          status: area['onclick'][/status=\w+/].split('=')[1]
        })
      end
    end

    @cache = @geojson.clone
    @cache["features"] = parking_spaces
    @cache[:timestamp] = Time.parse(doc.css('strong')[0].text).to_i
    @cache[:fetch_time] = fetch_time
    @cache
  end
end
