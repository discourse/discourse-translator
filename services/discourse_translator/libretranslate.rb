# frozen_string_literal: true

require_relative 'base'
require 'json'

module DiscourseTranslator
  class LibreTranslate < Base
    MAXLENGTH = 5000

    SUPPORTED_LANG = {
      en: 'en',
      en_US: 'en',
      en_GB: 'en',
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

    def self.translate_uri
      SiteSetting.translator_libretranslate_endpoint + "/translate"
    end

    def self.detect_uri
      SiteSetting.translator_libretranslate_endpoint + "/detect"
    end

    def self.support_uri
      SiteSetting.translator_libretranslate_endpoint + "/languages"
    end

    def self.access_token_key
      "libretranslate-translator"
    end

    def self.access_token
      SiteSetting.translator_libretranslate_api_key
    end

    def self.detect(post)
      res = result(detect_uri,
        q: ActionController::Base.helpers.strip_tags(post.cooked).truncate(MAXLENGTH, omission: nil)
      )

      if !res.empty?
        post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= res[0]["language"]
      else
        post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= "en"
      end
    end

    def self.translate_supported?(source, target)
      lang = SUPPORTED_LANG[target]
      res = result(support_uri, {})
      res.any? { |obj| obj["code"] == source } && res.any? { |obj| obj["code"] == lang }
    end

    def self.translate(post)
      detected_lang = detect(post)

      raise I18n.t('translator.failed') unless translate_supported?(detected_lang, I18n.locale)

      translated_text = from_custom_fields(post) do
        res = result(translate_uri,
          q: ActionController::Base.helpers.strip_tags(post.cooked).truncate(MAXLENGTH, omission: nil),
          source: detected_lang,
          target: SUPPORTED_LANG[I18n.locale]
        )
        res["translatedText"]
      end

      [detected_lang, translated_text]
    end

    def self.result(url, body)
      body[:api_key] = access_token

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
        body
      end
    end
  end
end
