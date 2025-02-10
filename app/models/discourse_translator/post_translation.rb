# frozen_string_literal: true

module DiscourseTranslator
  class PostTranslation < ActiveRecord::Base
    self.table_name = "discourse_translator_post_translations"

    belongs_to :post

    validates :post_id, presence: true
    validates :locale, presence: true
    validates :translation, presence: true
    validates :locale, uniqueness: { scope: :post_id }

    def self.translation_for(post_id, locale)
      find_by(post_id: post_id, locale: locale)&.translation
    end
  end
end

# == Schema Information
#
# Table name: discourse_translator_post_translations
#
#  id          :bigint           not null, primary key
#  post_id     :integer          not null
#  locale      :string           not null
#  translation :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_on_post_id_locale_0cc3d81e5b  (post_id,locale) UNIQUE
#
