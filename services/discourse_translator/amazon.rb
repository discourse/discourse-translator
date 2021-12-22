# frozen_string_literal: true

require_relative 'base'

module DiscourseTranslator
  class Amazon < Base
    require 'aws-sdk-translate'

    MAXLENGTH = 5000

    SUPPORTED_LANG = {
      af: 'af',
      sq: 'sq',
      am: 'am',
      ar: 'ar',
      hy: 'hy',
      az: 'az',
      bn: 'bn',
      bs: 'bs',
      bg: 'bg',
      ca: 'ca',
      zh: 'zh',
      zh_TW: 'zh-TW',
      hr: 'hr',
      cs: 'cs',
      da: 'da',
      fa_AF: 'fa-AF',
      nl: 'nl',
      en: 'en',
      et: 'et',
      fa: 'fa',
      tl: 'tl',
      fi: 'fi',
      fr: 'fr',
      fr_CA: 'fr-CA',
      ka: 'ka',
      de: 'de',
      el: 'el',
      gu: 'gu',
      ht: 'ht',
      ha: 'ha',
      he: 'he',
      hi: 'hi',
      hu: 'hu',
      is: 'is',
      id: 'id',
      ga: 'ga',
      it: 'it',
      ja: 'ja',
      kn: 'kn',
      kk: 'kk',
      ko: 'ko',
      lv: 'lv',
      lt: 'lt',
      mk: 'mk',
      ms: 'ms',
      ml: 'ml',
      mt: 'mt',
      mr: 'mr',
      mn: 'mn',
      no: 'no',
      ps: 'ps',
      pl: 'pl',
      pt: 'pt',
      pt_PT: 'pt-PT',
      pa: 'pa',
      ro: 'ro',
      ru: 'ru',
      sr: 'sr',
      si: 'si',
      sk: 'sk',
      sl: 'sl',
      so: 'so',
      es: 'es',
      es_MX: 'es-MX',
      sw: 'sw',
      sv: 'sv',
      ta: 'ta',
      te: 'te',
      th: 'th',
      tr: 'tr',
      uk: 'uk',
      ur: 'ur',
      uz: 'uz',
      vi: 'vi',
      cy: 'cy'
    }

    def self.access_token_key
      "aws-translator"
    end

    def self.detect(post)
      detected_lang = client.translate_text({
        text: post.cooked.truncate(MAXLENGTH, omission: nil),
        source_language_code: 'auto',
        target_language_code: SUPPORTED_LANG[I18n.locale]
      })&.source_language_code

      assign_lang_custom_field(post, detected_lang)
    end

    def self.translate(post)
      from_custom_fields(post) do
        result = client.translate_text({
          text: post.cooked.truncate(MAXLENGTH, omission: nil),
          source_language_code: "auto",
          target_language_code: SUPPORTED_LANG[I18n.locale],
        })

        detected_lang = assign_lang_custom_field(post, result.source_language_code)

        [detected_lang, result.translated_text]
      end
    rescue Aws::Translate::Errors::UnsupportedLanguagePairException
      raise I18n.t('translator.failed')
    end

    def self.client
      opts = {}
      if SiteSetting.translator_aws_key_id && SiteSetting.translator_aws_secret_access
        opts[:access_key_id] = SiteSetting.translator_aws_key_id
        opts[:secret_access_key] = SiteSetting.translator_aws_secret_access
        opts[:region] = SiteSetting.translator_aws_region
      end

      @client ||= Aws::Translate::Client.new(opts)
    end

    def self.assign_lang_custom_field(post, value)
      return post.custom_fields.delete(DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD) if value.nil?
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= value
    end

  end
end
