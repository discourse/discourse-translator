# frozen_string_literal: true

module DiscourseTranslator
  module Extensions
    module TagExtension
      extend ActiveSupport::Concern
      prepended { before_update :clear_translations, if: :name_changed? }
      include Translatable
    end
  end
end
