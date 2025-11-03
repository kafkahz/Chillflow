#!/bin/bash

# ChillFlow DMG 打包脚本

set -e

APP_NAME="ChillFlow"
DMG_NAME="ChillFlow"
VERSION="1.0"

# 构建路径
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/ChillFlow-*/Build/Products/Release"
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "ChillFlow.app" -path "*/Release/*" | head -1)

if [ -z "$APP_PATH" ]; then
    echo "错误: 找不到构建的应用程序"
    echo "请先运行: xcodebuild -project ChillFlow.xcodeproj -scheme ChillFlow -configuration Release build"
    exit 1
fi

echo "找到应用程序: $APP_PATH"

# 创建临时目录
DMG_TEMP="build/dmg"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# 复制应用程序
echo "复制应用程序..."
cp -R "$APP_PATH" "$DMG_TEMP/"

# 创建 Applications 链接（方便用户拖拽安装）
echo "创建 Applications 链接..."
ln -s /Applications "$DMG_TEMP/Applications"

# 创建 DMG
DMG_FILE="build/${DMG_NAME}.dmg"
rm -f "$DMG_FILE"
rm -f "$DMG_FILE.tmp.dmg"

echo "创建 DMG 文件..."
hdiutil create -srcfolder "$DMG_TEMP" -volname "$DMG_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 100m "$DMG_FILE.tmp.dmg" 2>&1

# 挂载 DMG
echo "挂载 DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_FILE.tmp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')

# 获取挂载点
DMG_MOUNT="/Volumes/$DMG_NAME"

# 等待设备就绪并验证挂载
sleep 3
if [ ! -d "$DMG_MOUNT" ]; then
    echo "错误: DMG 挂载失败"
    exit 1
fi

# 验证是否可写
for i in 1 2 3; do
    if touch "$DMG_MOUNT/.test_write" 2>/dev/null; then
        rm -f "$DMG_MOUNT/.test_write"
        echo "✓ DMG 已成功挂载为可写模式"
        break
    else
        if [ $i -lt 3 ]; then
            echo "等待 DMG 可写模式就绪 (尝试 $i/3)..."
            sleep 2
        else
            echo "警告: DMG 挂载为只读模式，尝试重新挂载..."
            hdiutil detach "$DEVICE" 2>/dev/null || true
            sleep 2
            DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_FILE.tmp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
            DMG_MOUNT="/Volumes/$DMG_NAME"
            sleep 3
        fi
    fi
done

# 设置 DMG 图标（如果存在）
# 优先使用 ICNS 文件（如果用户直接提供了 ICNS）
ICON_SOURCE="build/dmg_icon.png"
ICON_ICNS="build/dmg_icon.icns"
VOLUME_ICON="$DMG_MOUNT/.VolumeIcon.icns"

if [ -f "$ICON_ICNS" ]; then
    # 如果已经存在 ICNS 文件，直接使用（用户直接提供的 ICNS 文件）
    echo "使用 ICNS 图标文件: $ICON_ICNS"
    if [ -d "$DMG_MOUNT" ]; then
        echo "复制图标到 DMG: $VOLUME_ICON"
        cp "$ICON_ICNS" "$VOLUME_ICON"
        # 设置图标为隐藏文件
        chflags hidden "$VOLUME_ICON" 2>/dev/null || true
        # 使用 SetFile 设置卷图标属性（C 表示自定义图标）
        if command -v SetFile &> /dev/null; then
            SetFile -a C "$DMG_MOUNT"
            echo "✓ 使用 SetFile 设置卷图标属性"
        else
            echo "警告: SetFile 不可用"
        fi
        # 刷新 Finder
        sleep 1
        echo "✓ DMG 图标已设置"
    else
        echo "警告: DMG 挂载点不存在: $DMG_MOUNT"
    fi
elif [ -f "$ICON_SOURCE" ]; then
    # 如果没有 ICNS 文件，但有 PNG 文件，则转换为 ICNS
    echo "从 PNG 转换图标..."
    # 创建临时 iconset
    ICONSET_DIR="build/dmg_icon.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    
    # 生成不同尺寸的图标（DMG 需要 512x512）
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
    sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
    
    # 转换为 ICNS
    if iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS" 2>/dev/null; then
        echo "✓ PNG 已转换为 ICNS"
        rm -rf "$ICONSET_DIR"
        
        # 复制图标到 DMG
        if [ -f "$ICON_ICNS" ] && [ -d "$DMG_MOUNT" ]; then
            echo "复制图标到 DMG: $VOLUME_ICON"
            cp "$ICON_ICNS" "$VOLUME_ICON"
            chflags hidden "$VOLUME_ICON" 2>/dev/null || true
            if command -v SetFile &> /dev/null; then
                SetFile -a C "$DMG_MOUNT"
                echo "✓ 使用 SetFile 设置卷图标属性"
            fi
            sleep 1
            echo "✓ DMG 图标已设置"
        fi
    else
        echo "警告: iconutil 转换失败"
        rm -rf "$ICONSET_DIR"
    fi
else
    echo "提示: 未找到图标文件（$ICON_ICNS 或 $ICON_SOURCE），跳过图标设置"
fi

# 设置 DMG 窗口属性
echo '
   tell application "Finder"
     tell disk "'$DMG_NAME'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 920, 420}
           set viewOptions to the icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 72
           set position of item "'$APP_NAME'.app" of container window to {160, 205}
           set position of item "Applications" of container window to {360, 205}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
' | osascript

# 在 Finder 设置后再次确认图标（AppleScript 可能会影响图标设置）
sync
sleep 2

if [ -f "$ICON_ICNS" ] && [ -d "$DMG_MOUNT" ]; then
    echo "最终确认图标设置..."
    # 确保图标文件存在且正确设置
    VOL_ICON="$DMG_MOUNT/.VolumeIcon.icns"
    if [ ! -f "$VOL_ICON" ] || [ "$ICON_ICNS" -nt "$VOL_ICON" ]; then
        cp "$ICON_ICNS" "$VOL_ICON"
    fi
    # 设置隐藏属性（必须，否则图标不会显示为卷图标）
    chflags hidden "$VOL_ICON" 2>/dev/null || true
    # 设置正确的权限
    chmod 644 "$VOL_ICON" 2>/dev/null || true
    # 设置卷图标属性（关键步骤）- 必须在卸载前完成
    if command -v SetFile &> /dev/null; then
        SetFile -a C "$DMG_MOUNT"
        echo "✓ 卷图标属性已设置 (SetFile -a C)"
    else
        echo "⚠ SetFile 不可用，图标可能不会显示"
        echo "  请安装 Xcode Command Line Tools: xcode-select --install"
    fi
    # 验证图标文件属性
    if [ -f "$VOL_ICON" ]; then
        ATTR=$(ls -lO "$VOL_ICON" | grep -o "hidden\|uchg" || echo "")
        if [ -n "$ATTR" ]; then
            echo "✓ 图标文件属性: $ATTR"
        fi
    fi
    sync
    sleep 2
    echo "✓ 图标设置完成"
fi

# 卸载
hdiutil detach "$DEVICE"

# 转换为只读的最终 DMG（使用 -ov 保留卷属性）
echo "创建最终的 DMG 文件..."
hdiutil convert "$DMG_FILE.tmp.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_FILE"

# 清理
rm -f "$DMG_FILE.tmp.dmg"
rm -rf "$DMG_TEMP"

echo ""
echo "✓ DMG 创建成功: $DMG_FILE"
echo "文件大小: $(du -h "$DMG_FILE" | cut -f1)"
echo ""
echo "可以分享这个 DMG 文件给你的朋友了！"

