# frozen_string_literal: true

module DiscourseTranslator
  module TopicExtension
    extend ActiveSupport::Concern
    prepended { before_update :clear_translations, if: :title_changed? }
    include Translatable
  end
end
