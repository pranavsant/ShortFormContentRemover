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
        "window.__SL_CONFIG = \(json(config));\n" + core
    }

    static let core = #"""
(function () {
  'use strict';
  if (window.__SL_apply) { window.__SL_apply(window.__SL_CONFIG || {}); return; }

  var cfg = window.__SL_CONFIG || {};
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
  var IG_VIDEO_POSTS = 'main article[data-sl-video]';
  var IG_EXPLORE_GRID = 'html.sl-explore main a[href^="/p/"], html.sl-explore main a[href^="/reel/"]';
  var IG_HOME_FEED = 'html.sl-home main article';

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
    'html.sl-home ytm-browse ytm-rich-grid-renderer',
    'html.sl-home ytm-browse ytm-section-list-renderer',
    'html.sl-home ytd-browse[page-subtype="home"] #primary'
  ].join(',\n');

  // One rule per selector: if WebKit rejects one selector, only that rule is dropped.
  function each(list) { return list.split(',\n').map(function (s) { return s + HIDE; }).join('\n'); }

  function buildCSS() {
    var r = [];
    if (site === 'ig') {
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
    el.classList.toggle('sl-home', p === '/');
    el.classList.toggle('sl-explore', site === 'ig' && /^\/explore\/?$/.test(p));
  }

  function ensureStyle() {
    var parent = document.head || document.documentElement;
    if (!parent) { return; }
    var style = document.getElementById('sl-style');
    if (!style) {
      style = document.createElement('style');
      style.id = 'sl-style';
      parent.appendChild(style);
    }
    var css = buildCSS();
    if (style.textContent !== css) { style.textContent = css; }
  }

  // Tag every feed post that has (or ever had) a video. The tag is permanent
  // for that element, so the post stays hidden when Instagram unloads the video.
  function markVideoPosts() {
    if (site !== 'ig') { return; }
    var videos = document.querySelectorAll('main article:not([data-sl-video]) video');
    for (var i = 0; i < videos.length; i++) {
      var post = videos[i].closest('article');
      if (post) { post.setAttribute('data-sl-video', ''); }
    }
  }

  function tick() { updateClasses(); ensureStyle(); markVideoPosts(); }

  window.__SL_apply = function (newCfg) { cfg = newCfg || {}; tick(); };

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
