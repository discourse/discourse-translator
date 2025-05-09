import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Service | translator", function (hooks) {
  setupTest(hooks);

  test("translatePost - standard translation", async function (assert) {
    const service = this.owner.lookup("service:translator");

    pretender.post("/translator/translate", () => {
      return response({
        detected_lang: "ja",
        translation: "I am a cat",
        title_translation: "Surprise!",
      });
    });

    const post = {
      id: 1,
      post_number: 2,
    };

    await service.translatePost(post);

    assert.strictEqual(post.detectedLang, "ja");
    assert.strictEqual(post.translatedText, "I am a cat");
    assert.strictEqual(post.translatedTitle, "Surprise!");
  });

  test("clearPostTranslation", function (assert) {
    const service = this.owner.lookup("service:translator");

    const post = {
      detectedLang: "ja",
      translatedText: "Hello",
      translatedTitle: "Title",
    };

    service.clearPostTranslation(post);

    assert.strictEqual(post.detectedLang, null);
    assert.strictEqual(post.translatedText, null);
    assert.strictEqual(post.translatedTitle, null);
  });
});
