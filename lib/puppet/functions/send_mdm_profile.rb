# I wish this was Go. Or Python. Or anything else. But here we are.

require "net/http"
require "net/https"
require "uri"
require "json"
require "base64"

require "puppet/util/plist" if Puppet.features.cfpropertylist?

Puppet::Functions.create_function(:send_mdm_profile) do
  def send_mdm_profile(mobileconfig, udid, ensure_profile, mdmdirector_username, mdmdirector_password, mdmdirector_host, mdmdirector_path = "/profile")
    enc = Base64.encode64(mobileconfig)
    unless mdmdirector_path.start_with?("/")
      mdmdirector_path = "/" + mdmdirector_path
    end
    uri = URI.parse(mdmdirector_host + mdmdirector_path)
    http = Net::HTTP.new(uri.host, uri.port)

    if ensure_profile == "absent"
      request = Net::HTTP::Delete.new(uri.request_uri)
      # also need to parse out the payload id from the plist
      plist = Puppet::Util::Plist.parse_plist(mobileconfig)

      request.body = JSON.dump({
        "udids" => [udid],
        "profiles" => [{
          "payload_identifier" => plist["PayloadIdentifier"],
          "uuid" => plist["PayloadUUID"],
        }],
        "metadata" => true,
      })
    else
      request = Net::HTTP::Post.new(uri.request_uri)
      data = {
        "udids" => [udid],
        "profiles" => [enc],
        "metadata" => true,
        "push_now" => true,
      }
      request.body = data.to_json
    end

    if uri.scheme == "https"
      http.use_ssl = true
    else
      http.use_ssl = false
    end
    request.basic_auth(mdmdirector_username, mdmdirector_password)

    response = http.request(request)

    Puppet.debug(response)
    JSON.parse(response.body)
  end
end