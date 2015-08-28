module DiscourseTranslator
  class Microsoft < Base
    DATA_URI = "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13".freeze
    SCOPE_URI = "http://api.microsofttranslator.com".freeze
    GRANT_TYPE = "client_credentials".freeze
    TRANSLATE_URI = "http://api.microsofttranslator.com/V2/Http.svc/Translate".freeze
    DETECT_URI = "http://api.microsofttranslator.com/V2/Http.svc/Detect".freeze

    def self.access_token_key
      "microsoft-translator"
    end

    def self.access_token
      access_token = $redis.get(cache_key)

      if access_token
        return access_token
      else
        body = URI.encode_www_form(
          client_id: SiteSetting.translator_client_id,
          client_secret: SiteSetting.translator_client_secret,
          scope: SCOPE_URI,
          grant_type: GRANT_TYPE
        )

        response = Excon.post(DATA_URI,
          headers: { "Content-Type" => "application/x-www-form-urlencoded" },
          body: body
        )

        body = JSON.parse(response.body)

        if response.status == 200
          access_token = body["access_token"]
          $redis.setex(cache_key, body["expires_in"].to_i - 1.minute, access_token)
          access_token
        else
          raise TranslatorError.new("#{body['error']}: #{body['error_description']}")
        end
      end
    end

    def self.detect(post)
      result(DETECT_URI, text: post.cooked)
    end

    def self.translate(post)
      body = result(TRANSLATE_URI,
        text: post.cooked,
        to: I18n.locale,
        contentType: 'text/html'
      )

      Nokogiri::XML(body).text
    end

    private

    def result(uri, query)
      response = Excon.get(uri,
        query: query,
        headers: { 'Authorization' => "Bearer #{access_token}" }
      )

      if response.status != 200
        body = JSON.parse(response.body)
        raise TranslatorError.new("#{body['error']}: #{body['error_description']}")
      end

      response.body
    end
  end
end
