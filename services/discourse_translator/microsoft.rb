module DiscourseTranslator
  class Microsoft < Base
    DATA_URI = "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13".freeze
    SCOPE_URI = "http://api.microsofttranslator.com".freeze
    GRANT_TYPE = "client_credentials".freeze
    TRANSLATE_URI = "http://api.microsofttranslator.com/V2/Http.svc/Translate".freeze
    DETECT_URI = "http://api.microsofttranslator.com/V2/Http.svc/Detect".freeze

    SUPPORTED_LANG = {
      en: 'en',
      bs_BA: 'bs-Latn',
      cs: 'cs',
      da: 'da',
      de: 'de',
      ar: 'ar',
      es: 'es',
      fi: 'fi',
      fr: 'fr',
      he: 'he',
      id: 'id',
      it: 'it',
      ja: 'ja',
      ko: 'ko',
      nl: 'nl',
      pt: 'pt',
      ro: 'ro',
      ru: 'ru',
      sv: 'sv',
      uk: 'uk',
      zh_CN: 'zh-CHT',
      zh_TW: 'zh-CHS',
      tr_TR: 'tr',
      te: nil,
      sq: nil,
      pt_BR: 'pt',
      pl_PL: 'pl',
      no_NO: 'no',
      fa_IR: 'fa'
    }

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
      if detected_lang = post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]
        detected_lang
      else
        detected_lang = result(DETECT_URI, text: post.cooked)
        post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = detected_lang
        post.save!
        detected_lang
      end
    end

    def self.translate(post)
      detected_lang = detect(post)
      post_translated_custom_field = post.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] ||= {}.to_json
      post_translated_custom_field = JSON.parse(post_translated_custom_field).with_indifferent_access

      if !post_translated_custom_field || !(translated_text = post_translated_custom_field[I18n.locale])
        translated_text = result(TRANSLATE_URI,
          text: post.cooked,
          from: detected_lang,
          to: locale,
          contentType: 'text/html'
        )

        post.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD] =
          post_translated_custom_field.merge({ I18n.locale => translated_text  })

        post.save!
      end

      [detected_lang, translated_text]
    end

    private

    def self.locale
      SUPPORTED_LANG[I18n.locale] || (raise "This language is not supported by the translator")
    end

    def self.result(uri, query)
      response = Excon.get(uri,
        query: query,
        headers: { 'Authorization' => "Bearer #{access_token}" }
      )

      if response.status != 200
        body = JSON.parse(response.body)
        raise TranslatorError.new("#{body['error']}: #{body['error_description']}")
      end

      Nokogiri::XML(response.body).text
    end
  end
end
