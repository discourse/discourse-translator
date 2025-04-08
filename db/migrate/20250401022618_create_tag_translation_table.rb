# frozen_string_literal: true

class CreateTagTranslationTable < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_translator_tag_locales do |t|
      t.integer :tag_id, null: false
      t.string :detected_locale, limit: 20, null: false
      t.timestamps
    end

    create_table :discourse_translator_tag_translations do |t|
      t.integer :tag_id, null: false
      t.string :locale, null: false
      t.text :translation, null: false
      t.timestamps
    end

    add_index :discourse_translator_tag_translations,
              %i[tag_id locale],
              unique: true,
              name: "idx_tag_translations_on_tag_id_and_locale"
  end
end
