# frozen_string_literal: true

module DiscourseTranslator
  module Extensions
    module PostExtension
      extend ActiveSupport::Concern
      prepended { before_update :clear_translations, if: :raw_changed? }
      include Translatable
    end
  end
end
