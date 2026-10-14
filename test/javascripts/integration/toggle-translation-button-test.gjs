import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ToggleTranslationButton from "discourse/plugins/discourse-translator/discourse/components/post-menu/toggle-translation-button";

module("Integration | Component | toggle-translation-button", function (hooks) {
  setupRenderingTest(hooks);

  test("doesn't render when post cannot be translated", async function (assert) {
    this.set("post", { can_translate: false });

    await render(
      <template><ToggleTranslationButton @post={{this.post}} /></template>
    );

    assert.dom("button").doesNotExist();
  });

  test("renders translation button with correct states", async function (assert) {
    const post = {
      can_translate: true,
      isTranslated: false,
      isTranslating: false,
    };

    this.set("post", post);

    await render(
      <template>
        <ToggleTranslationButton @post={{this.post}} @showLabel={{true}} />
      </template>
    );

    assert.dom("button").exists();
    assert.dom("button").hasText("View translation");
    assert.dom("button").doesNotHaveClass("translated");

    post.isTranslating = true;
    await render(
      <template>
        <ToggleTranslationButton @post={{this.post}} @showLabel={{true}} />
      </template>
    );
    assert.dom("button").hasAttribute("disabled");
    assert.dom("button").hasText("Translating");

    post.isTranslating = false;
    post.isTranslated = true;
    await render(
      <template>
        <ToggleTranslationButton @post={{this.post}} @showLabel={{true}} />
      </template>
    );
    assert.dom("button").hasClass("translated");
    assert.dom("button").hasText("Hide translation");
  });
});
