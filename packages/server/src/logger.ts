// SPDX-FileCopyrightText: Copyright Orangebot, Inc. and Medplum contributors
// SPDX-License-Identifier: Apache-2.0
import { LogLevel, Logger } from '@medplum/core';
import { once } from 'node:events';
import { requestContextStore } from './request-context-store';

// Initialize BetterStack (Logtail) if token is provided
let logtail: any = null;
if (process.env.LOGTAIL_SOURCE_TOKEN) {
  try {
    // Dynamic import to avoid breaking if package not installed
    import('@logtail/node').then((module) => {
      logtail = new module.Logtail(process.env.LOGTAIL_SOURCE_TOKEN as string);
    }).catch(() => {
      console.warn('BetterStack (@logtail/node) not installed, logs will only go to stdout');
    });
  } catch (err) {
    console.warn('Failed to initialize BetterStack:', err);
  }
}

export function writeLineToStdout(msg: string): void {
  // Always write to stdout (CloudWatch)
  process.stdout.write(msg + '\n');
  
  // Also send to BetterStack if configured
  if (logtail) {
    try {
      const parsed = JSON.parse(msg);
      const level = parsed.level?.toLowerCase() || 'info';
      const message = parsed.msg || msg;
      const context = { ...parsed };
      delete context.msg;
      delete context.level;
      
      // Send to BetterStack with proper level
      logtail[level] ? logtail[level](message, context) : logtail.info(message, context);
    } catch (err) {
      // If parsing fails, send raw message
      logtail?.info(msg);
    }
  }
}

export async function drainStdout(): Promise<void> {
  // Flush BetterStack logs first
  if (logtail) {
    try {
      await logtail.flush();
    } catch (err) {
      console.error('Failed to flush BetterStack logs:', err);
    }
  }
  
  // Then drain stdout
  if (!process.stdout.writableNeedDrain) {
    return;
  }
  await once(process.stdout, 'drain');
}

/**
 * Awaits stdout drain before calling `process.exit(code)`.
 *
 * `process.exit` immediately kills the process without flushing buffered writes,
 * so callers that have just written via `stdout.write` (e.g. final error logs)
 * must await drain themselves to avoid losing the last lines on exit.
 *
 * @param code - The exit code to pass to `process.exit`. Defaults to 1.
 */
export async function exitAfterStdoutDrain(code = 1): Promise<void> {
  await drainStdout();
  process.exit(code);
}

export const globalLogger = new Logger(
  writeLineToStdout,
  undefined,
  process.env.NODE_ENV === 'test' ? LogLevel.ERROR : LogLevel.INFO
);

/**
 * @returns the current `IRequestContext.logger` if available, otherwise `globalLogger`
 */
export function getLogger(): Logger {
  return requestContextStore.getStore()?.logger ?? globalLogger;
}
