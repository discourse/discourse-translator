import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import cookie, { removeCookie } from "discourse/lib/cookie";

const SHOW_ORIGINAL_COOKIE = "discourse-translator-show-original";
const SHOW_ORIGINAL_COOKIE_EXPIRY = 30;

export default class ShowOriginalContent extends Component {
  static shouldRender(args) {
    return (
      args.topic.is_translated ||
      args.topic.postStream.posts.some(({ is_translated }) => is_translated)
    );
  }

  @service router;

  @tracked showingOriginal = false;

  constructor() {
    super(...arguments);
    this.showingOriginal = cookie(SHOW_ORIGINAL_COOKIE);
  }

  @action
  async showOriginal() {
    if (this.showingOriginal) {
      removeCookie(SHOW_ORIGINAL_COOKIE, { path: "/" });
    } else {
      cookie(SHOW_ORIGINAL_COOKIE, true, {
        path: "/",
        expires: SHOW_ORIGINAL_COOKIE_EXPIRY,
      });
    }

    window.location.reload();
  }

  get title() {
    return this.showingOriginal
      ? "translator.content_not_translated"
      : "translator.content_translated";
  }

  <template>
    <div class="discourse-translator_toggle-original">
      <DButton
        @icon="language"
        @title={{this.title}}
        class={{concatClass
          "btn btn-default"
          (unless this.showingOriginal "active")
        }}
        @action={{this.showOriginal}}
      />
    </div>
  </template>
}
