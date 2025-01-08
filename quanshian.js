// 全时安给爷爬
// 运行输入 tester.start()
// 结束输入 tester.stop()
// 视频播放测试工具

function videoPlaybackTester() {
    let isRunning = false;
    let completedVideos = 0;

    function findNextButton() {
        const buttons = Array.from(document.getElementsByTagName('button'));
        return buttons.find(button => 
            button.textContent.includes('下一') || 
            button.innerText.includes('下一')
        );
    }

    // 检查是否出现最后单元的提示
    function checkLastUnitPrompt() {
        const allText = document.body.innerText;
        return allText.includes('最后一单元') || allText.includes('已经是最后');
    }

    function findElements() {
        const video = document.querySelector('video');
        const nextButton = findNextButton();
        return { video, nextButton };
    }

    function waitForVideo(video) {
        return new Promise((resolve, reject) => {
            if (video.readyState >= 3 && isFinite(video.duration)) {
                resolve();
            } else {
                video.addEventListener('loadeddata', () => {
                    if (isFinite(video.duration)) {
                        resolve();
                    } else {
                        reject(new Error('视频duration无效'));
                    }
                });
                setTimeout(() => reject(new Error('视频加载超时')), 10000);
            }
        });
    }

    async function skipVideo(video) {
        try {
            await waitForVideo(video);
            if (isFinite(video.duration)) {
                video.currentTime = video.duration - 0.1;
                video.play();
            }
        } catch (error) {
            console.log('跳过视频时出错:', error);
            return false;
        }
        return true;
    }

    async function runTest() {
        if (!isRunning) return;

        try {
            // 检查是否显示最后单元提示
            if (checkLastUnitPrompt()) {
                console.log('检测到最后一单元提示，测试完成！');
                stop();
                return;
            }

            const { video, nextButton } = findElements();
            
            if (!video) {
                console.log('未找到视频元素，等待重试...');
                setTimeout(runTest, 2000);
                return;
            }

            const success = await skipVideo(video);
            if (success) {
                completedVideos++;
                console.log(`已完成测试第 ${completedVideos} 个视频`);
            }

            await new Promise(resolve => setTimeout(resolve, 2000));

            // 再次检查是否为最后一单元
            if (checkLastUnitPrompt()) {
                console.log('检测到最后一单元提示，测试完成！');
                stop();
                return;
            }

            if (nextButton) {
                console.log('找到下一个按钮，正在点击...');
                nextButton.click();
                setTimeout(runTest, 2000);
            } else {
                console.log('未找到下一个按钮，等待重试...');
                setTimeout(runTest, 2000);
            }
        } catch (error) {
            console.log('测试过程出错:', error);
            stop();
        }
    }

    function start() {
        isRunning = true;
        console.log('开始视频播放测试');
        runTest();
    }

    function stop() {
        isRunning = false;
        console.log(`测试结束，共完成 ${completedVideos} 个视频的测试`);
    }

    return {
        start,
        stop,
        getStats: () => ({ completedVideos, isRunning })
    };
}

const tester = videoPlaybackTester();
