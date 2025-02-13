# frozen_string_literal: true

module Jobs
  class TranslateTranslatable < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.translator_enabled
      return if SiteSetting.automatic_translation_target_languages.blank?

      translatable = args[:type].constantize.find_by(id: args[:translatable_id])
      return if translatable.blank?

      target_locales = SiteSetting.automatic_translation_target_languages.split("|")
      target_locales.each do |target_locale|
        "DiscourseTranslator::#{SiteSetting.translator}".constantize.translate(
          translatable,
          target_locale.to_sym,
        )
      end

      topic_id = translatable.is_a?(Post) ? translatable.topic.id : translatable.id
      post_id = translatable.is_a?(Post) ? translatable.id : 1
      MessageBus.publish("/topic/#{topic_id}", type: :revised, id: post_id)
    end
  end
end
