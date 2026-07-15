import { z } from 'zod'

const app = z.string().min(1)
const revision = z.string().min(1)
const coordinateTarget = {
  x: z.number().nonnegative().optional(),
  y: z.number().nonnegative().optional(),
  element_index: z.number().int().nonnegative().optional(),
}

export const TOOL_SCHEMAS = {
  list_apps: z.object({}).strict(),
  observe: z.object({
    app,
    include_screenshot: z.boolean().optional().default(true),
  }),
  click: z
    .object({
      app,
      revision,
      ...coordinateTarget,
      button: z.enum(['left', 'right']).optional().default('left'),
      click_count: z.number().int().min(1).max(2).optional().default(1),
    })
    .refine(
      (value) =>
        value.element_index !== undefined ||
        (value.x !== undefined && value.y !== undefined),
      'Provide element_index or both x and y.',
    ),
  type_text: z.object({ app, revision, text: z.string().min(1) }),
  press_key: z.object({
    app,
    revision,
    key: z.string().min(1),
    modifiers: z.array(z.string()).optional().default([]),
  }),
  scroll: z.object({
    app,
    revision,
    ...coordinateTarget,
    delta_x: z.number().optional().default(0),
    delta_y: z.number(),
  }),
} as const

export type ToolName = keyof typeof TOOL_SCHEMAS

const commonAppProperty = {
  app: {
    type: 'string',
    description: 'Target macOS application bundle identifier.',
  },
} as const
const revisionProperty = {
  revision: {
    type: 'string',
    description: 'Opaque revision returned by the latest observe call.',
  },
} as const

export const TOOL_DEFINITIONS = [
  {
    name: 'list_apps',
    description: 'List running macOS GUI applications and their bundle identifiers.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'observe',
    description: 'Observe one allowed app and return its AX tree, revision, and optional screenshot.',
    inputSchema: {
      type: 'object',
      properties: {
        ...commonAppProperty,
        include_screenshot: { type: 'boolean', default: true },
      },
      required: ['app'],
      additionalProperties: false,
    },
  },
  {
    name: 'click',
    description: 'Click an observed element or window-relative coordinate.',
    inputSchema: {
      type: 'object',
      properties: {
        ...commonAppProperty,
        ...revisionProperty,
        element_index: { type: 'integer', minimum: 0 },
        x: { type: 'number', minimum: 0 },
        y: { type: 'number', minimum: 0 },
        button: { type: 'string', enum: ['left', 'right'], default: 'left' },
        click_count: { type: 'integer', minimum: 1, maximum: 2, default: 1 },
      },
      required: ['app', 'revision'],
      additionalProperties: false,
    },
  },
  {
    name: 'type_text',
    description: 'Type Unicode text into the focused non-secure field of an observed app.',
    inputSchema: {
      type: 'object',
      properties: {
        ...commonAppProperty,
        ...revisionProperty,
        text: { type: 'string', minLength: 1 },
      },
      required: ['app', 'revision', 'text'],
      additionalProperties: false,
    },
  },
  {
    name: 'press_key',
    description: 'Press a supported key with optional modifiers in an observed app.',
    inputSchema: {
      type: 'object',
      properties: {
        ...commonAppProperty,
        ...revisionProperty,
        key: { type: 'string', minLength: 1 },
        modifiers: { type: 'array', items: { type: 'string' }, default: [] },
      },
      required: ['app', 'revision', 'key'],
      additionalProperties: false,
    },
  },
  {
    name: 'scroll',
    description: 'Scroll at an observed element, coordinate, or window center.',
    inputSchema: {
      type: 'object',
      properties: {
        ...commonAppProperty,
        ...revisionProperty,
        element_index: { type: 'integer', minimum: 0 },
        x: { type: 'number', minimum: 0 },
        y: { type: 'number', minimum: 0 },
        delta_x: { type: 'number', default: 0 },
        delta_y: { type: 'number' },
      },
      required: ['app', 'revision', 'delta_y'],
      additionalProperties: false,
    },
  },
] as const
