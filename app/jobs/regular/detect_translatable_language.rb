# frozen_string_literal: true

module ::Jobs
  class DetectTranslatableLanguage < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.translator_enabled

      translatable = args[:type].constantize.find_by(id: args[:translatable_id])
      return if translatable.blank?
      begin
        translator = "DiscourseTranslator::#{SiteSetting.translator}".constantize
        translator.detect(translatable)
      rescue ::DiscourseTranslator::ProblemCheckedTranslationError
        # problem-checked translation errors gracefully
      end
    end
  end
end
