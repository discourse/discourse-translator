# frozen_string_literal: true

require_relative 'base'
require 'json'

module DiscourseTranslator
  class Google < Base
    TRANSLATE_URI = "https://www.googleapis.com/language/translate/v2".freeze
    DETECT_URI = "https://www.googleapis.com/language/translate/v2/detect".freeze
    SUPPORT_URI = "https://www.googleapis.com/language/translate/v2/languages".freeze
    MAXLENGTH = 5000

    SUPPORTED_LANG = {
      en: 'en',
      en_GB: 'en',
      en_US: 'en',
      bs_BA: 'bs',
      cs: 'cs',
      da: 'da',
      de: 'de',
      ar: 'ar',
      es: 'es',
      fi: 'fi',
      fr: 'fr',
      he: 'iw',
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
      lv: 'lv',
      et: 'et',
      zh_CN: 'zh-CN',
      zh_TW: 'zh-TW',
      tr_TR: 'tr',
      te: 'te',
      sq: nil,
      pt_BR: 'pt',
      pl_PL: 'pl',
      no_NO: 'no',
      nb_NO: 'no',
      fa_IR: 'fa'
    }

    def self.access_token_key
      "google-translator"
    end

    def self.access_token
      SiteSetting.translator_google_api_key || (raise TranslatorError.new("NotFound: Google Api Key not set."))
    end

    def self.detect(post)
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||=
        result(DETECT_URI,
          q: post.cooked.truncate(MAXLENGTH, omission: nil)
        )["detections"][0].max { |a, b| a.confidence <=> b.confidence }["language"]
    end

    def self.translate_supported?(source, target)
      res = result(SUPPORT_URI, target: SUPPORTED_LANG[target])
      res["languages"].any? { |obj| obj["language"] == source }
    end

    def self.translate(post)
      detected_lang = detect(post)

      raise I18n.t('translator.failed') unless translate_supported?(detected_lang, I18n.locale)

      translated_text = from_custom_fields(post) do
        res = result(TRANSLATE_URI,
          q: post.cooked.truncate(MAXLENGTH, omission: nil),
          source: detected_lang,
          target: SUPPORTED_LANG[I18n.locale]
        )
        res["translations"][0]["translatedText"]
      end

      [detected_lang, translated_text]
    end

    def self.result(url, body)
      body[:key] = access_token

      response = Excon.post(url,
        body: URI.encode_www_form(body),
        headers: { "Content-Type" => "application/x-www-form-urlencoded" }
      )

      body = nil
      begin
        body = JSON.parse(response.body)
      rescue JSON::ParserError
      end

      if response.status != 200
        raise TranslatorError.new(body || response.inspect)
      else
        body["data"]
      end
    end
  end
end
