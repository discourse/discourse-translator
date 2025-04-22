# frozen_string_literal: true

module DiscourseTranslator
  module Provider
    class TranslatorProvider
      def self.get
        "DiscourseTranslator::Provider::#{SiteSetting.translator_provider}".constantize
      end
    end
  end
end
