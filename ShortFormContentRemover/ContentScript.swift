import Foundation

/// The JavaScript injected into every page at document start.
/// It adds a <style> tag that hides short-form content, and keeps it in place
/// as the single-page apps re-render. Selectors are the part that breaks when
/// Instagram/YouTube change their markup — they all live in this file.
enum ContentScript {
    static func json(_ config: BlockConfig) -> String {
        guard let data = try? JSONEncoder().encode(config),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }

    static func source(config: BlockConfig) -> String {
        "window.__SFR_CONFIG = \(json(config));\n" + core
    }

    static let core = #"""
(function () {
  'use strict';
  if (window.__SFR_apply) { window.__SFR_apply(window.__SFR_CONFIG || {}); return; }

  var cfg = window.__SFR_CONFIG || {};
  var host = location.hostname;
  var site = /(^|\.)instagram\.com$/.test(host) ? 'ig'
           : /(^|\.)youtube\.com$/.test(host) ? 'yt'
           : null;
  if (!site) { return; }

  var HIDE = ' { display: none !important; }';

  // ---- Instagram (mobile web) ----
  var IG_REELS_NAV = 'a[href="/reels/"], a[href^="/reels/"]';
  // Marked by markVideoPosts() rather than matched live with :has(video).
  // Instagram removes the <video> from posts that aren't visible, so a live
  // :has(video) rule would hide -> unhide -> hide in a loop (flicker).
  var IG_VIDEO_POSTS = 'main article[data-sfr-video]';
  var IG_EXPLORE_GRID = 'html.sfr-explore main a[href^="/p/"], html.sfr-explore main a[href^="/reel/"]';
  var IG_HOME_FEED = 'html.sfr-home main article';

  // ---- YouTube (m.youtube.com, plus desktop equivalents) ----
  var YT_SHORTS = [
    'ytm-reel-shelf-renderer',
    'ytm-shorts-lockup-view-model',
    'ytm-shorts-lockup-view-model-v2',
    'ytm-rich-section-renderer:has(ytm-shorts-lockup-view-model)',
    'ytm-rich-section-renderer:has(ytm-shorts-lockup-view-model-v2)',
    'ytm-rich-section-renderer:has(ytm-reel-shelf-renderer)',
    'ytm-item-section-renderer:has(ytm-reel-shelf-renderer)',
    'ytm-pivot-bar-item-renderer:has(.pivot-shorts)',
    'ytm-video-with-context-renderer:has(a[href^="/shorts/"])',
    'ytm-compact-video-renderer:has(a[href^="/shorts/"])',
    'grid-shelf-view-model',
    'ytd-reel-shelf-renderer',
    'ytd-rich-shelf-renderer[is-shorts]',
    'ytd-rich-section-renderer:has(ytd-rich-shelf-renderer[is-shorts])',
    'ytd-video-renderer:has(a[href^="/shorts/"])',
    'ytd-guide-entry-renderer:has(a[title="Shorts"])',
    'ytd-mini-guide-entry-renderer:has(a[title="Shorts"])'
  ].join(',\n');
  var YT_HOME_FEED = [
    'html.sfr-home ytm-browse ytm-rich-grid-renderer',
    'html.sfr-home ytm-browse ytm-section-list-renderer',
    'html.sfr-home ytd-browse[page-subtype="home"] #primary'
  ].join(',\n');

  // One rule per selector: if WebKit rejects one selector, only that rule is dropped.
  function each(list) { return list.split(',\n').map(function (s) { return s + HIDE; }).join('\n'); }

  function buildCSS() {
    var r = [];
    if (site === 'ig') {
      r.push('[data-sfr-banner]' + HIDE);
      if (cfg.igBlockReelsFeed) { r.push(IG_REELS_NAV + HIDE); }
      if (cfg.igHideVideoPosts) { r.push(IG_VIDEO_POSTS + HIDE); }
      if (cfg.igHideExploreGrid) { r.push(IG_EXPLORE_GRID + HIDE); }
      if (cfg.igHideHomeFeed) { r.push(IG_HOME_FEED + HIDE); }
    } else if (site === 'yt') {
      if (cfg.ytBlockShorts) { r.push(each(YT_SHORTS)); }
      if (cfg.ytHideHomeFeed) { r.push(each(YT_HOME_FEED)); }
    }
    return r.join('\n');
  }

  // Page-type classes on <html>, so CSS can target "home" or "explore" only.
  function updateClasses() {
    var el = document.documentElement;
    if (!el) { return; }
    var p = location.pathname;
    el.classList.toggle('sfr-home', p === '/');
    el.classList.toggle('sfr-explore', site === 'ig' && /^\/explore\/?$/.test(p));
  }

  function ensureStyle() {
    var parent = document.head || document.documentElement;
    if (!parent) { return; }
    var style = document.getElementById('sfr-style');
    if (!style) {
      style = document.createElement('style');
      style.id = 'sfr-style';
      parent.appendChild(style);
    }
    var css = buildCSS();
    if (style.textContent !== css) { style.textContent = css; }
  }

  // Tag every feed post that has (or ever had) a video. The tag is permanent
  // for that element, so the post stays hidden when Instagram unloads the video.
  function markVideoPosts() {
    if (site !== 'ig') { return; }
    var videos = document.querySelectorAll('main article:not([data-sfr-video]) video');
    for (var i = 0; i < videos.length; i++) {
      var post = videos[i].closest('article');
      if (post) { post.setAttribute('data-sfr-video', ''); }
    }
  }

  // Instagram's "Use the app" prompt pinned to the bottom of the page.
  // Its markup has no stable class names, so find it by its text and hide the
  // fixed-position bar that contains it.
  var BANNER_TEXTS = ['Use the app', 'Open app', 'Open Instagram'];
  function hideAppBanners() {
    if (site !== 'ig' || !document.body) { return; }
    var candidates = document.querySelectorAll('a, button, div[role="button"], span');
    for (var i = 0; i < candidates.length; i++) {
      var el = candidates[i];
      if (BANNER_TEXTS.indexOf((el.textContent || '').trim()) === -1) { continue; }
      for (var node = el, depth = 0; node && node !== document.body && depth < 10; node = node.parentElement, depth++) {
        var pos = getComputedStyle(node).position;
        if (pos === 'fixed' || pos === 'sticky') {
          node.setAttribute('data-sfr-banner', '');
          break;
        }
      }
    }
  }

  function tick() { updateClasses(); ensureStyle(); markVideoPosts(); hideAppBanners(); }

  window.__SFR_apply = function (newCfg) { cfg = newCfg || {}; tick(); };

  tick();
  document.addEventListener('DOMContentLoaded', tick);
  // Catch new posts as soon as they're added, before they get painted.
  if (site === 'ig' && window.MutationObserver) {
    new window.MutationObserver(markVideoPosts)
      .observe(document.documentElement, { childList: true, subtree: true });
  }
  // SPA navigations and re-renders: cheap enough to just re-check.
  setInterval(tick, 400);
})();
"""#
}
