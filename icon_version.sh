# icons_path和icons_dest_path路径，修改为自己工程，实际的图标资源路径或名称。

#!/bin/sh

#取当前时间字符串添加到文件结尾
nowTime=$(date +%m.%d-%H:%M:%S)
#当前工程绝对路径
PROJECT_DIR=$(pwd)
convertPath=`which convert`
echo ${convertPath}
# 判断convertPath文件是否存在 如果不错在就提示安装imagemagick和ghostscript
if [[ ! -f ${convertPath} || -z ${convertPath} ]]; then
    echo "您需要先安装ImageMagick和ghostscript \nwarning: Skipping Icon versioning, you need to install ImageMagick and ghostscript (fonts) first, you can use brew to simplify process: \nbrew install imagemagick \nbrew install ghostscript"
    exit -1;
fi


# 说明 拼接所需要显示的内容
# version    app-版本号
version=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${CONFIGURATION_BUILD_DIR}/${INFOPLIST_PATH}"`
# build_num  app-构建版本号
build_num=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${CONFIGURATION_BUILD_DIR}/${INFOPLIST_PATH}"`
# 检查当前所处Git分支
if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
    # commit     git-提交哈希值
    commit=`git rev-parse --short HEAD`
    # branch     git-分支名
    branch=`git rev-parse --abbrev-ref HEAD`
else
    # commit     git-提交哈希值
    commit=`hg identify -i`
    # branch     git-分支名
    branch=`hg identify -b`
fi;


shopt -s extglob
build_num="${build_num##*( )}"
shopt -u extglob
# 拼接所要显示的内容
#caption="${version}($build_num)\n${branch}\n${commit}"
caption="${version}($build_num)\n${branch}\n${nowTime}"
echo $caption


function processIcon() {
    base_file=$1
    temp_path=$2
    dest_path=$3
    if [[ ! -e $base_file ]]; then
        echo "error: file does not exist: ${base_file}"
        exit -1;
    fi
    if [[ -z $temp_path ]]; then
        echo "error: temp_path does not exist: ${temp_path}"
        exit -1;
    fi
    if [[ -z $dest_path ]]; then
        echo "error: dest_path does not exist: ${dest_path}"
        exit -1;
    fi
    file_name=$(basename "$base_file")
    final_file_path="${dest_path}/${file_name}"
    base_tmp_normalizedFileName="${file_name%.*}-normalized.${file_name##*.}"
    base_tmp_normalizedFilePath="${temp_path}/${base_tmp_normalizedFileName}"

    # Normalize 正常化
    echo "Reverting optimized PNG to normal\n将优化的PNG恢复为正常"
    echo "xcrun -sdk iphoneos pngcrush -revert-iphone-optimizations -q '${base_file}' '${base_tmp_normalizedFilePath}'"
    xcrun -sdk iphoneos pngcrush -revert-iphone-optimizations -q "${base_file}" "${base_tmp_normalizedFilePath}"
    width=`identify -format %w "${base_tmp_normalizedFilePath}"`
    height=`identify -format %h "${base_tmp_normalizedFilePath}"`
    # 文字条高度和位置
    band_height=$((($height * 50) / 100))
    band_position=$(($height - $band_height))
    # 文字位置
    text_position=$(($band_position - 8))
    point_size=$(((12 * $width) / 100))
    echo "Image dimensions ($width x $height) - band height $band_height @ $band_position - point size $point_size"
    #
    # blur band and text
    # 模糊和文字
    #
    # 添加高斯模糊  截取相应部分
    convert "${base_tmp_normalizedFilePath}" -blur 10x8 /tmp/blurred.png
    convert /tmp/blurred.png -gamma 0 -fill white -draw "rectangle 0,$band_position,$width,$height" /tmp/mask.png
    # 添加文字
    convert -size ${width}x${band_height} xc:none -fill 'rgba(0,0,0,0.2)' -draw "rectangle 0,0,$width,$band_height" /tmp/labels-base.png
    convert -background none -size ${width}x${band_height} -pointsize $point_size -fill white -gravity center -gravity South caption:"$caption" /tmp/labels.png
    # 合成文字和文字条
    convert "${base_tmp_normalizedFilePath}" /tmp/blurred.png /tmp/mask.png -composite /tmp/temp.png
    rm /tmp/blurred.png
    rm /tmp/mask.png
    #
    # compose final image
    # 合成最终图像
    #
    filename=New"${base_file}"
    convert /tmp/temp.png /tmp/labels-base.png -geometry +0+$band_position -composite /tmp/labels.png -geometry +0+$text_position -geometry +${w}-${h} -composite -alpha remove "${final_file_path}"
    # clean up
    rm /tmp/temp.png
    rm /tmp/labels-base.png
    rm /tmp/labels.png
    rm "${base_tmp_normalizedFilePath}"
    echo "Overlayed ${final_file_path}"
}


# Process all app icons and create the corresponding internal icons
# 处理所有应用程序图标并创建相应的内部图标
# icons_dir="${SRCROOT}/Images.xcassets/AppIcon.appiconset"
#工程名 自动获取，注意修改工程后缀名 xcodeproj/xcworkspace
project_name=$(find . -name *.xcodeproj | awk -F "[/.]" '{print $(NF-1)}')
icons_path="${PROJECT_DIR}/${project_name}/Assets.xcassets/AppIcon.appiconset"
icons_dest_path="${PROJECT_DIR}/${project_name}/Assets.xcassets/AppIcon-Internal.appiconset"
#icons_set=`basename "${icons_path}"`
tmp_path="${TEMP_DIR}/IconVersioning"
echo "icons_path: ${icons_path}"
echo "icons_dest_path: ${icons_dest_path}"
mkdir -p "${tmp_path}"
if [[ $icons_dest_path == "\\" ]]; then
    echo "error: destination file path can't be the root directory"
    exit -1;
fi
rm -rf "${icons_dest_path}"
cp -rf "${icons_path}" "${icons_dest_path}"
# Reference: https://askubuntu.com/a/343753
find "${icons_path}" -type f -name "*.png" -print0 |
while IFS= read -r -d '' file; do
    echo "$file"
    processIcon "${file}" "${tmp_path}" "${icons_dest_path}"
done