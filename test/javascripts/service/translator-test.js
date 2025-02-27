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

  test("translatePost - with experimental translation for first post", async function (assert) {
    const service = this.owner.lookup("service:translator");

    service.siteSettings.experimental_topic_translation = true;

    let headerUpdateCalled = false;
    let postStreamRefreshCalled = false;
    let titleSet = null;

    service.appEvents.on(
      "header:update-topic",
      () => (headerUpdateCalled = true)
    );
    service.appEvents.on(
      "post-stream:refresh",
      () => (postStreamRefreshCalled = true)
    );
    service.documentTitle.setTitle = (title) => (titleSet = title);

    pretender.post("/translator/translate", () => {
      return response({
        detected_lang: "ja",
        translation: "I am a cat",
        title_translation: "Surprise!",
      });
    });

    const topic = {
      set: function (key, value) {
        this[key] = value;
      },
    };
    const post = {
      id: 1,
      post_number: 1,
      topic,
      set: function (key, value) {
        this[key] = value;
      },
    };

    await service.translatePost(post);

    assert.true(headerUpdateCalled);
    assert.true(postStreamRefreshCalled);
    assert.strictEqual(titleSet, "Surprise!");
    assert.strictEqual(post.cooked, "I am a cat");
    assert.false(post.can_translate);
    assert.strictEqual(topic.fancy_title, "Surprise!");
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
