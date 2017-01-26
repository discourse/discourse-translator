# discourse-translator

![](example.gif)

## Translation Services Supported
* [Microsoft Translator](http://www.microsoft.com/en-us/translator/default.aspx)
* [Google Translate - Comming Soon](https://cloud.google.com/translate/)

## Installation

https://meta.discourse.org/t/install-a-plugin/19157

## Setup

### Microsoft

1. Subscribe to the [Microsoft Translator API on Azure](https://translatorbusiness.uservoice.com/knowledgebase/articles/1078534-action-required-before-april-30-2017-microsoft-t#signup). Basic subscriptions, up to 2 million characters a month, are free. Translating more than 2 million characters per month requires a payment. You may pick from any of the available subscription offers.

2. Under Admin > Settings > Plugins, enter the subscription key that you've obtained from the steps above.
![](setup.png)

3. Under Admin > Settings > Basic Setup, enable allow user locale.

## Known Issues
* Does not translate text within polls plugin.

## TODOS
* Allow admin to set quota and disable translation once quota has been exceeded.
* Google Translate Adapter.
* `Translated from #{language}` should be localized too.
