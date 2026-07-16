/**
 * ClassDumpSearch - Frida 版（无需 Mac 编译 dylib）
 *
 * 仅做 Runtime 检索 + 打印 Markdown 报告，不 Hook、不改返回值、不强制会员。
 *
 * 用法（电脑已装 frida-tools，手机有 frida-server 或可附加进程）：
 *
 *   # USB，按包名 spawn
 *   frida -U -f com.example.app -l class_dump_search.js --no-pause
 *
 *   # 附加已运行进程
 *   frida -U com.example.app -l class_dump_search.js
 *
 *   # 在 Frida REPL 里手动搜：
 *   // rpc.exports.search("vip", 200)
 *   // rpc.exports.searchAll("vip", 100)  // 全进程类，更慢
 *
 * 巨魔 / 无越狱：若只能注入 gadget，把本脚本作为 gadget 配置的 script。
 */

'use strict';

const DEFAULT_MAX = 200;
const APP_OWN_ONLY = true;

function safeStr(s) {
  try {
    if (s === null || s === undefined) return '';
    return String(s);
  } catch (e) {
    return '';
  }
}

function containsCI(hay, needle) {
  if (!hay || !needle) return false;
  return hay.toLowerCase().indexOf(needle.toLowerCase()) !== -1;
}

function getBundleId() {
  try {
    const NSBundle = ObjC.classes.NSBundle;
    if (!NSBundle) return 'unknown';
    const main = NSBundle.mainBundle();
    const bid = main.bundleIdentifier();
    return bid ? safeStr(bid.toString()) : 'unknown';
  } catch (e) {
    return 'unknown';
  }
}

function getAppBundlePath() {
  try {
    const NSBundle = ObjC.classes.NSBundle;
    const main = NSBundle.mainBundle();
    const path = main.bundlePath();
    return path ? safeStr(path.toString()) : '';
  } catch (e) {
    return '';
  }
}

function isAppOwnClass(cls, bundlePath) {
  if (!APP_OWN_ONLY) return true;
  if (!bundlePath) return true;
  try {
    // class_getImageName via api
    const namePtr = cls.$className ? null : null;
    // Frida: Module path from class
    const api = new ApiResolver('objc');
    // Use ObjC.api.class_getImageName if available
    const class_getImageName = new NativeFunction(
      Module.findExportByName(null, 'class_getImageName'),
      'pointer',
      ['pointer']
    );
    const imgPtr = class_getImageName(cls.handle);
    if (imgPtr.isNull()) return false;
    const img = imgPtr.readUtf8String();
    if (!img) return false;
    return img.indexOf(bundlePath) === 0;
  } catch (e) {
    // 解析失败时宁可多报，不要崩
    return true;
  }
}

function matchTypeName(t) {
  switch (t) {
    case 'class': return '类名';
    case 'imethod': return '实例方法';
    case 'cmethod': return '类方法';
    case 'prop': return '属性';
    default: return '未知';
  }
}

/**
 * @param {string} keyword
 * @param {number} maxResults
 * @param {boolean} appOwnOnly
 */
function search(keyword, maxResults, appOwnOnly) {
  if (!ObjC.available) {
    return { error: 'ObjC runtime not available', results: [], report: '' };
  }

  const kw = safeStr(keyword).trim();
  if (!kw) {
    return { error: 'empty keyword', results: [], report: '' };
  }

  const limit = maxResults > 0 ? maxResults : DEFAULT_MAX;
  const onlyOwn = (appOwnOnly === undefined) ? APP_OWN_ONLY : !!appOwnOnly;
  const bundlePath = getAppBundlePath();
  const results = [];

  const classes = ObjC.enumerateLoadedClassesSync();
  // classes: { modulePath: [className, ...] }
  const moduleNames = Object.keys(classes);

  outer:
  for (let mi = 0; mi < moduleNames.length; mi++) {
    const mod = moduleNames[mi];
    if (onlyOwn && bundlePath && mod.indexOf(bundlePath) !== 0) {
      continue;
    }
    const list = classes[mod] || [];
    for (let ci = 0; ci < list.length; ci++) {
      if (results.length >= limit) break outer;

      const className = list[ci];
      if (!className) continue;

      try {
        if (containsCI(className, kw)) {
          results.push({ className: className, type: 'class', name: className });
          if (results.length >= limit) break outer;
        }

        if (!ObjC.classes[className]) continue;
        const cls = ObjC.classes[className];

        // 实例方法
        const methods = cls.$ownMethods || [];
        for (let i = 0; i < methods.length; i++) {
          if (results.length >= limit) break outer;
          const m = methods[i];
          // $ownMethods 通常带 - / + 前缀
          const pure = m.replace(/^[\-\+]\s*/, '');
          if (containsCI(pure, kw) || containsCI(m, kw)) {
            const isClass = m.trim().charAt(0) === '+';
            results.push({
              className: className,
              type: isClass ? 'cmethod' : 'imethod',
              name: pure || m
            });
          }
        }
      } catch (e) {
        // 单类失败继续
      }
    }
  }

  // 属性：再用一遍（Frida 对 property 访问）
  if (results.length < limit) {
    try {
      for (let mi = 0; mi < moduleNames.length; mi++) {
        const mod = moduleNames[mi];
        if (onlyOwn && bundlePath && mod.indexOf(bundlePath) !== 0) continue;
        const list = classes[mod] || [];
        for (let ci = 0; ci < list.length; ci++) {
          if (results.length >= limit) break;
          const className = list[ci];
          try {
            const cls = ObjC.classes[className];
            if (!cls) continue;
            // 通过 runtime API 取属性
            const class_copyPropertyList = new NativeFunction(
              Module.findExportByName(null, 'class_copyPropertyList'),
              'pointer',
              ['pointer', 'pointer']
            );
            const property_getName = new NativeFunction(
              Module.findExportByName(null, 'property_getName'),
              'pointer',
              ['pointer']
            );
            const freeFn = new NativeFunction(
              Module.findExportByName(null, 'free'),
              'void',
              ['pointer']
            );
            const countPtr = Memory.alloc(4);
            countPtr.writeU32(0);
            const props = class_copyPropertyList(cls.handle, countPtr);
            const count = countPtr.readU32();
            if (!props.isNull() && count > 0) {
              for (let pi = 0; pi < count; pi++) {
                if (results.length >= limit) break;
                const prop = props.add(pi * Process.pointerSize).readPointer();
                if (prop.isNull()) continue;
                const namePtr = property_getName(prop);
                if (namePtr.isNull()) continue;
                const pname = namePtr.readUtf8String();
                if (containsCI(pname, kw)) {
                  results.push({ className: className, type: 'prop', name: pname });
                }
              }
              freeFn(props);
            }
          } catch (e) {}
        }
      }
    } catch (e) {}
  }

  const report = formatReport(kw, results);
  return { error: null, results: results, report: report };
}

function formatReport(keyword, results) {
  const lines = [];
  lines.push('# iOS 应用逆向分析报告');
  lines.push('## 搜索关键词: ' + keyword);
  lines.push('## Bundle ID: ' + getBundleId());
  lines.push('----');
  lines.push('找到 ' + results.length + ' 个相关结果：');
  lines.push('');
  lines.push('> 仅分析导出，未修改任何运行时状态。');
  lines.push('');
  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    lines.push((i + 1) + '. [' + r.className + ']');
    lines.push('   匹配类型：' + matchTypeName(r.type));
    lines.push('   名称：' + r.name);
  }
  return lines.join('\n');
}

function copyPasteboard(text) {
  try {
    ObjC.schedule(ObjC.mainQueue, function () {
      try {
        const UIPasteboard = ObjC.classes.UIPasteboard;
        if (!UIPasteboard) return;
        const pb = UIPasteboard.generalPasteboard();
        pb.setString_(text);
        console.log('[ClassDumpSearch] copied to pasteboard, length=' + text.length);
      } catch (e) {
        console.log('[ClassDumpSearch] pasteboard error: ' + e);
      }
    });
  } catch (e) {
    console.log('[ClassDumpSearch] schedule pasteboard error: ' + e);
  }
}

// 启动后默认不自动扫，避免卡顿；你手动调用
rpc.exports = {
  search: function (keyword, maxResults) {
    const r = search(keyword, maxResults || DEFAULT_MAX, true);
    if (r.report) {
      console.log(r.report);
      copyPasteboard(r.report);
    }
    return r;
  },
  searchAll: function (keyword, maxResults) {
    const r = search(keyword, maxResults || DEFAULT_MAX, false);
    if (r.report) {
      console.log(r.report);
      copyPasteboard(r.report);
    }
    return r;
  },
  ping: function () {
    return 'ClassDumpSearch frida ok, bundle=' + getBundleId();
  }
};

console.log('[ClassDumpSearch] Frida script loaded.');
console.log('[ClassDumpSearch] 用法: rpc.exports.search("vip", 200)');
console.log('[ClassDumpSearch] 全量: rpc.exports.searchAll("vip", 100)');
console.log('[ClassDumpSearch] ' + rpc.exports.ping());
