# frozen_string_literal: true

module DiscourseTranslator
  class CategoryTranslation < ActiveRecord::Base
    self.table_name = "discourse_translator_category_translations"

    belongs_to :category

    validates :category_id, presence: true
    validates :locale, presence: true
    validates :translation, presence: true
    validates :locale, uniqueness: { scope: :category_id }
  end
end

# == Schema Information
#
# Table name: discourse_translator_category_translations
#
#  id          :bigint           not null, primary key
#  category_id :integer          not null
#  locale      :string           not null
#  translation :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_category_translations_on_category_id_and_locale  (category_id,locale) UNIQUE
#
