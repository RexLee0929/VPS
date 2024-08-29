// ==UserScript==
// @name         Kox.Moe 批量下载
// @author       Rex Lee
// @version      1.0
// @description  kox 批量下载 epub
// @match        https://kox.moe/c/*
// ==/UserScript==

// 处理链接点击事件
async function handleLinkClick(text) {
  function sleep(_timeout) {
    return new Promise(resolve => setTimeout(resolve, _timeout));
  }

  var links = document.querySelectorAll('a[href]');

  for (var i = 0; i < links.length; i++) {
    var link = links[i];
    if (link.textContent.indexOf(text) > -1) {
      // 找到最近的 <td> 元素
      var td = link.closest('td');
      // 检查 <td> 内是否有复选框且是否已选中
      var checkbox = td.querySelector('input[type="checkbox"]');
      if (checkbox && checkbox.checked) {
        console.log("download", link);
        link.click();
        await sleep(4000); // 等待4秒
      }
    }
  }
  return;
};

// 主函数
(function () {
  var epub = document.getElementById('div_epub');

  function createButton(text, onClickHandler) {
    var button = document.createElement("button");
    button.textContent = text;
    button.style.padding = "8px 12px"; // 内边距
    button.style.border = "none"; // 无边框
    button.style.borderRadius = "4px"; // 边角圆润
    button.style.backgroundColor = "#007bff"; // 背景颜色
    button.style.color = "#fff"; // 字体颜色
    button.style.cursor = "pointer"; // 鼠标指针为手型
    button.style.fontSize = "14px"; // 字体大小
    button.style.transition = "background-color 0.3s, transform 0.2s"; // 过渡效果
    button.style.flex = "1"; // 使按钮在容器中填充
    button.style.maxWidth = "120px"; // 最大宽度

    button.onmouseover = function() {
      button.style.backgroundColor = "#0056b3"; // 鼠标悬停时背景颜色
      button.style.transform = "scale(1.05)"; // 鼠标悬停时放大效果
    };

    button.onmouseout = function() {
      button.style.backgroundColor = "#007bff"; // 鼠标移出时背景颜色
      button.style.transform = "scale(1)"; // 鼠标移出时恢复大小
    };

    button.onclick = onClickHandler; // 设置点击事件处理函数
    return button;
  }

  var buttonContainer = document.createElement("div");
  buttonContainer.style.display = "flex"; // 使用 Flexbox 布局
  buttonContainer.style.justifyContent = "center"; // 水平居中
  buttonContainer.style.alignItems = "center"; // 垂直居中
  buttonContainer.style.gap = "458px"; // 按钮之间的间距
  buttonContainer.style.width = "100%"; // 容器宽度填满父容器

  var button1 = createButton("VIP下載", function() {
    handleLinkClick("VIP下載");
  });
  buttonContainer.appendChild(button1);

  var button2 = createButton("VIP線路2", function() {
    handleLinkClick("VIP線路2");
  });
  buttonContainer.appendChild(button2);

  var wrapper = document.createElement("div");
  wrapper.style.textAlign = "center"; // 居中文本
  wrapper.style.width = "100%"; // 确保包裹容器填满宽度
  wrapper.appendChild(buttonContainer);

  var cell = document.createElement("td");
  cell.colSpan = 5; // 跨越5列
  cell.style.textAlign = "center"; // 居中文本
  cell.style.padding = "0px 5px 0px 15px"; // 内边距
  cell.appendChild(wrapper);

  epub.appendChild(cell); // 将单元格添加到容器中
})();
