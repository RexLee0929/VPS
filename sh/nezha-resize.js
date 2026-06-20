// ==UserScript==
// @name         Replace resize-none -> resize-y
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  将目标站点中含有 resize-none 的元素（且包含 min-h-[80px]）替换为 resize-y
// @author       You
// @match        https://nezha.rexleepro.com/*
// @grant        none
// @run-at       document-end
// ==/UserScript==

(function () {
    'use strict';
    function isTarget(el) {
        if (!el || el.nodeType !== 1 || !el.classList) return false;
        // 只匹配同时包含这两个类的元素，尽量精准
        return el.classList.contains('min-h-[80px]') && el.classList.contains('resize-none');
    }
    function processElement(el) {
        if (!isTarget(el)) return;
        // 替换类名 resize-none -> resize-y
        if (typeof el.classList.replace === 'function') {
            el.classList.replace('resize-none', 'resize-y');
        } else {
            el.classList.remove('resize-none');
            el.classList.add('resize-y');
        }
        // 仅当没有内联 height 时，设置默认高度为 300px
        try {
            if (!el.style || !el.style.height || el.style.height.trim() === '') {
                el.style.height = '300px';
            }
        } catch (e) {
            // 忽略异常
        }
    }
    function scan(root) {
        if (!root || !root.querySelectorAll) return;
        // 找出可能包含目标类字符串的元素，随后用 isTarget 精确判断
        var candidates = root.querySelectorAll('[class*="min-h-[80px]"][class*="resize-none"]');
        candidates.forEach(function (el) { processElement(el); });
    }
    // 初次扫描整个文档
    scan(document);
    // 监听动态添加或者 class 变化
    var observer = new MutationObserver(function (mutations) {
        mutations.forEach(function (m) {
            if (m.type === 'childList') {
                m.addedNodes.forEach(function (node) {
                    if (node.nodeType === 1) {
                        processElement(node);
                        scan(node);
                    }
                });
            } else if (m.type === 'attributes' && m.attributeName === 'class') {
                processElement(m.target);
            }
        });
    });
    observer.observe(document.documentElement || document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['class']
    });
    // 页面完全加载后再跑一次以防遗漏
    window.addEventListener('load', function () { scan(document); });
})();
