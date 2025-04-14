import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class TranslatedPostIndicator extends Component {
  get tooltip() {
    return i18n("translator.originally_written_in", {
      language: this.args.data.detectedLanguage,
    });
  }

  <template>
    <DTooltip
      @identifier="discourse-translator_translated-post-indicator"
      @icon="language"
      @content={{this.tooltip}}
    />
  </template>
}
