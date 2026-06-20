// ==UserScript==
// @name         Replace resize-none -> resize-y
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  将目标站点中含有 resize-none 的元素（且包含 min-h-[80px]）替换为 resize-y
// @author       You
// @match        https://example.com/*    // <- 把这里改成你要运行的站点，例如 https://www.yoursite.com/*
// @grant        none
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    // 检查并处理单个元素
    function processElement(el) {
        if (!el || !el.classList) return;
        // 增加 min-h-[80px] 作为额外判断，减少误改其它元素
        if (el.classList.contains('resize-none') && el.classList.contains('min-h-[80px]')) {
            if (typeof el.classList.replace === 'function') {
                el.classList.replace('resize-none', 'resize-y');
            } else {
                el.classList.remove('resize-none');
                el.classList.add('resize-y');
            }
        }
    }

    // 扫描根节点下所有可能的目标节点
    function scanRoot(root) {
        if (!root || root.querySelectorAll === undefined) return;
        // 使用属性包含选择器快速定位包含 resize-none 的元素，再用 classList 做精确判断
        var candidates = root.querySelectorAll('[class*="resize-none"]');
        candidates.forEach(function(el) { processElement(el); });
    }

    // 初次扫描整个文档
    scanRoot(document);

    // 监听 DOM 变更（新增节点或 class 属性变化）
    var observer = new MutationObserver(function(muts) {
        muts.forEach(function(m) {
            if (m.type === 'attributes' && m.attributeName === 'class') {
                processElement(m.target);
            } else if (m.type === 'childList') {
                m.addedNodes.forEach(function(node) {
                    if (node.nodeType === 1) { // element
                        // 检查新增节点本身
                        processElement(node);
                        // 以及其子孙中可能的目标元素
                        scanRoot(node);
                    }
                });
            }
        });
    });

    observer.observe(document.documentElement || document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['class']
    });

    // 可选：在页面完全加载后再跑一次以确保覆盖某些延迟渲染的情况
    window.addEventListener('load', function() { scanRoot(document); });
})();
