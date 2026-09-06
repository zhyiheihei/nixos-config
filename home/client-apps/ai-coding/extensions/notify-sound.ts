// 通知扩展：pi 需要用户决策或一轮完成时发系统桌面通知
import { execFile } from 'node:child_process';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';

const DEBOUNCE_MS = 2000;

const lastShown = new Map<string, number>();

function notify(summary: string, body: string) {
	const now = Date.now();
	// 同标题短时间只发一次，避免密集事件刷通知
	if (now - (lastShown.get(summary) ?? 0) < DEBOUNCE_MS) return;
	lastShown.set(summary, now);
	const args = [
		'-a', 'pi',
		'-t', '5000',
		// Plasma 会按 sound-name 播放对应的系统提示音
		'-h', 'string:sound-name:dialog-information',
		summary,
		body,
	];
	try {
		execFile('notify-send', args, { timeout: 10_000 }, err => {
			// notify-send 不在 PATH 时退回 nix shell（首次拉包，之后走缓存）
			if (err && (err as NodeJS.ErrnoException).code === 'ENOENT') {
				execFile(
					'nix',
					['shell', 'nixpkgs#libnotify', '-c', 'notify-send', ...args],
					{ timeout: 120_000 },
					() => {},
				);
			}
		});
	} catch {
		// 无桌面/无 D-Bus 时静默失败
	}
}

export default function (pi: ExtensionAPI) {
	// 阻塞式 UI 弹窗（提问/确认/输入框等）→ 需要决策
	pi.on('ui_prompt_start', async event => {
		notify('pi 需要你的决策', event.title ?? '有弹窗等待你处理');
	});
	// 一轮结束、pi 空闲等待用户输入
	pi.on('agent_settled', async () => {
		notify('pi 已完成', '一轮任务结束，等待你的下一步指令');
	});
}
