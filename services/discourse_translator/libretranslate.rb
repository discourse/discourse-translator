# frozen_string_literal: true

require_relative 'base'
require 'json'

module DiscourseTranslator
  class LibreTranslate < Base
    MAXLENGTH = 5000

    SUPPORTED_LANG_MAPPING = {
      en: 'en',
      en_GB: 'en',
      en_US: 'en',
      ar: 'ar',
      bg: 'bg',
      bs_BA: 'bs',
      ca: 'ca',
      cs: 'cs',
      da: 'da',
      de: 'de',
      el: 'el',
      es: 'es',
      et: 'et',
      fi: 'fi',
      fr: 'fr',
      he: 'iw',
      hr: 'hr',
      hu: 'hu',
      hy: 'hy',
      id: 'id',
      it: 'it',
      ja: 'ja',
      ka: 'ka',
      kk: 'kk',
      ko: 'ko',
      ky: 'ky',
      lv: 'lv',
      mk: 'mk',
      nl: 'nl',
      pt: 'pt',
      ro: 'ro',
      ru: 'ru',
      sk: 'sk',
      sl: 'sl',
      sq: 'sq',
      sr: 'sr',
      sv: 'sv',
      tg: 'tg',
      te: 'te',
      th: 'th',
      uk: 'uk',
      uz: 'uz',
      zh_CN: 'zh',
      zh_TW: 'zh',
      tr_TR: 'tr',
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
      lang = SUPPORTED_LANG_MAPPING[target]
      res = get(support_uri)
      res.any? { |obj| obj["code"] == source } && res.any? { |obj| obj["code"] == lang }
    end

    def self.translate(post)
      detected_lang = detect(post)

      raise I18n.t('translator.failed') unless translate_supported?(detected_lang, I18n.locale)

      translated_text = from_custom_fields(post) do
        res = result(translate_uri,
          q: post.cooked.truncate(MAXLENGTH, omission: nil),
          source: detected_lang,
          target: SUPPORTED_LANG_MAPPING[I18n.locale],
          format: "html"
        )
        res["translatedText"]
      end

      [detected_lang, translated_text]
    end

    def self.get(url)
      response = Excon.get(url)

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
