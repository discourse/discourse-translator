import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | translated-post", function (hooks) {
  setupRenderingTest(hooks);

  test("renders translation when post is translated", async function (assert) {
    this.set("outletArgs", {
      post: {
        isTranslated: true,
        isTranslating: false,
        translatedText: "こんにちは",
        translatedTitle: "良い一日",
        detectedLang: "ja",
      },
    });

    this.siteSettings.translator_provider = "Google";

    await render(hbs`
      <TranslatedPost @outletArgs={{this.outletArgs}} />
    `);

    assert.dom(".post-translation").exists();
    assert.dom(".topic-attribution").hasText("良い一日");
    assert.dom(".post-attribution").hasText("Translated from ja by Google");
    assert.dom(".cooked").hasText("こんにちは");
  });
});
