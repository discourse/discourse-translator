# frozen_string_literal: true

class CreateCategoryTranslationTable < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_translator_category_locales do |t|
      t.integer :category_id, null: false
      t.string :detected_locale, limit: 20, null: false
      t.timestamps
    end

    create_table :discourse_translator_category_translations do |t|
      t.integer :category_id, null: false
      t.string :locale, null: false
      t.text :translation, null: false
      t.timestamps
    end

    add_index :discourse_translator_category_translations,
              %i[category_id locale],
              unique: true,
              name: "idx_category_translations_on_category_id_and_locale"
  end
end
