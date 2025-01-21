import Component from "@glimmer/component";
import {service} from "@ember/service";
import {action} from "@ember/object";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { tracked } from "@glimmer/tracking";
import I18n, { i18n } from "discourse-i18n";

export default class ShowOriginalContent extends Component {
  @service router;
  @tracked active = true;

  @action
  async showOriginal() {
    this.active = !this.active;
    // invoke decorateCookedElement directly?
  }

  get title() {
    return this.active
      ? "translator.hide_translation"
      : "translator.show_translation";
  }

  <template>
    <div class="discourse-translator_toggle-original">
      <DButton
        @icon="language"
        @title={{this.title}}
        class={{concatClass "btn btn-default" (if this.active "active")}}
        @action={{this.showOriginal}}
      >
      </DButton>
    </div>
  </template>
}
