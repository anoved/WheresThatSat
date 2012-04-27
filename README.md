Where's That Sat?
=================

[@WheresThatSat](https://twitter.com/#!/wheresthatsat) is a Twitter bot that provides location information about mentioned satellites. It is based on [Chatterbot](http://muffinlabs.com/chatterbot.html) and [Ground Track Generator](https://github.com/anoved/Ground-Track-Generator). Visit [wheresthatsat.com](http://wheresthatsat.com/) for more info!

Invoking the bot script performs a single update, which comprises replying to any queries received since the last update. In addition to responding to queries addressed to @WheresThatSat, the bot can optionally also search for and reply to any mentions of specified satellites (this is useful to actively broadcast information about "newsmaking" satellites - people seem like getting the nitty gritty details on the news they're posting about - but should be used sparingly to avoid seeming "spammy"). The bot script can be invoked periodically with `cron` or a similar tool. At present it runs every 10 minutes.

When responding to a tweet about a given satellite, it looks up the corresponding two-line element set (periodically retrieved from [CelesTrak](http://www.celestrak.com/). It gives the time of the tweet and the TLE to Ground Track Generator, which returns location information as well as other attribute data about the satellite's state. This data is packed into a URL parameter string and posted to Twitter. The URL leads to [wheresthatsat.com/map.html](http://wheresthatsat.com/map.html), where a Javascript renders the parameter data on an embedded Google Map. (Packing the data into the URL parameter string avoids the need for a database by essentially using Twitter's t.co URL shortening as the data store. A proper database-backed alternative is under consideration and will facilitate more features.)

The web site, including the `wheresthatsat.js` script that plots the parameter data, is available in the [`gh-pages`](https://github.com/anoved/WheresThatSat/tree/gh-pages) branch of this repository.

To report bugs or see a list of tentatively planned improvements, [see the Issues page](https://github.com/anoved/WheresThatSat/issues).
