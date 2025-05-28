import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import TranslatedPost from "discourse/plugins/discourse-translator/discourse/components/translated-post";

module("Integration | Component | translated-post", function (hooks) {
  setupRenderingTest(hooks);

  test("renders translation when post is translated", async function (assert) {
    const self = this;

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

    await render(
      <template><TranslatedPost @outletArgs={{self.outletArgs}} /></template>
    );

    assert.dom(".post-translation").exists();
    assert.dom(".topic-attribution").hasText("良い一日");
    assert.dom(".post-attribution").hasText("Translated from ja by Google");
    assert.dom(".cooked").hasText("こんにちは");
  });
});
