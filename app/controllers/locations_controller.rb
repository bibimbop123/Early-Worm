require "httparty"
require "time"
require "tzinfo"
require "timezone_finder"

class LocationsController < ApplicationController
  def index
  end

  def show
    query = params[:q]

    if query.blank?
      redirect_to root_path, alert: "Please enter a location."
      return
    end

    # Step 1: Geocode city name → lat/lng
    geo_url = "https://nominatim.openstreetmap.org/search"
    geo_response = HTTParty.get(
      geo_url,
      query: { q: query, format: "json", limit: 1 },
      headers: { "User-Agent" => "early_worm/1.0 (contact@example.com)" }
    )

    geo_json = geo_response.parsed_response
    if geo_json.blank? || geo_json.empty?
      redirect_to root_path, alert: "Location not found."
      return
    end

    geo_data = geo_json.first
    lat = geo_data["lat"].to_f
    lng = geo_data["lon"].to_f

    # Step 2: Get sunrise/sunset (UTC)
    sun_url = "https://api.sunrise-sunset.org/json"
    sun_response = HTTParty.get(sun_url, query: { lat: lat, lng: lng, formatted: 0 })

    unless sun_response.success?
      redirect_to root_path, alert: "Failed to fetch sunrise/sunset data."
      return
    end

    sun_data = sun_response.parsed_response["results"]

    # Step 3: Detect timezone automatically (no Google API)
    finder = TimezoneFinder.create
    tz_name = finder.timezone_at(lat: lat, lng: lng)

    if tz_name.present?
      tz = TZInfo::Timezone.get(tz_name)
      sunrise_utc = Time.parse(sun_data["sunrise"]).utc
      sunset_utc  = Time.parse(sun_data["sunset"]).utc

      @sunrise = tz.utc_to_local(sunrise_utc)
      @sunset  = tz.utc_to_local(sunset_utc)
    else
      # fallback if timezone lookup fails
      @sunrise = Time.parse(sun_data["sunrise"]).utc.localtime
      @sunset  = Time.parse(sun_data["sunset"]).utc.localtime
    end

    @location = query.titleize
    @day_length = sun_data["day_length"]

  rescue StandardError => e
    Rails.logger.error("Error fetching location data: #{e.message}")
    redirect_to root_path, alert: "An unexpected error occurred. Please try again."
  end
end
