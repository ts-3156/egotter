module CrawlersHelper
  def reject_crawler
    head :forbidden if from_crawler?
  end

  def from_crawler?
    request.from_crawler? || from_minor_crawler?(request.user_agent)
  end

  def twitter_crawler?
    request.from_crawler? && request.browser == 'twitter'
  end

  private

  CRAWLER_WORDS = [
      'Applebot',
      'Jooblebot',
      'SBooksNet',
      'AdsBot-Google-Mobile',
      'FlipboardProxy',
      'HeartRails_Capture',
      'Mail.RU_Bot',
      '360Spider',
      'Yahoo Ad monitoring',
      'KZ BRAIN Mobile',
      'Researchscan/t13rl',
      'Y!J-BRW/1.0',
      'NetcraftSurveyAgent',
      'https://',
      'http://',
      'PetalBot',
      'Seekport Crawler',
      'YandexBot',
      'ias-va/3.1',
      'ias-or/3.1',
      'ias-jp/3.1',
      'TTD-Content',
      'Barkrowler',
      'Hatena Antenna',
      'Daum/4.1',
      'TrendsmapResolver',
      'YaK/1.0',
      'Linespider',
      'PaperLiBot',
      'YandexMobileBot',
      'Yeti/1.1',
      'zgrab/0.x',
  ]
  CRAWLERS_REGEXP = Regexp.union(CRAWLER_WORDS)

  CRAWLERS_FULL_UA = [
      'WWWC/1.13',
      'Chrome',
      'Hatena::UserAgent/0.02',
      'Hatena-Favicon2 (http://www.hatena.ne.jp/faq/)',
      'Mozilla/5.0 (compatible; TrendsmapResolver/0.1)',
      'Mozilla/5.0 (compatible; evc-batch/2.0)',
      'Mozilla/5.0 zgrab/0.x',
      'Ruby',
      'bot',
      '',
  ]

  def from_minor_crawler?(user_agent)
    ua = user_agent.to_s
    ua.include?('Bot') || CRAWLERS_FULL_UA.include?(ua) || ua.match?(CRAWLERS_REGEXP)
  end

  def maybe_bot?
    !user_signed_in? && via_dm? && %i(SymbianOS BlackBerry Linux UNKNOWN).include?(request.os)
  end
end
