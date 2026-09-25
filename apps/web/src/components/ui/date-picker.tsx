// SPDX-FileCopyrightText: 2025 Guli Moreno
// SPDX-FileCopyrightText: 2026 Ignacio Garbayo
// SPDX-License-Identifier: MIT AND AGPL-3.0-or-later
//
// Adapted from a-good-date-picker (https://github.com/gulipad/a-good-date-picker),
// MIT License: full text in LICENSES/MIT.txt. Our own changes are
// AGPL-3.0-or-later.

"use client"

/**
 * DatePicker — reusable date (and time) picker for the whole app.
 *
 * Adapted from "a good date picker" by Guli Moreno
 * (https://github.com/gulipad/a-good-date-picker, MIT License,
 * Copyright (c) 2025 Guli Moreno): a natural language text field
 * (chrono-node) with a calendar (react-day-picker) as the alternative,
 * inside a Popover. The original component takes no props (fixed internal
 * state, no `value`/`onChange`); the controlled props from PR #2 of that
 * repo (https://github.com/gulipad/a-good-date-picker/pull/2) were ported
 * by hand, and also:
 *   - it uses this repo's primitives (Button, Input, Popover, Calendar,
 *     already restyled to the F0 design system, see
 *     specs/13-sistema-diseno.md) instead of the original repo's;
 *   - picking only the day in the calendar keeps the time already set
 *     (or 23:59 if there was none), because in Hackboard a date with no
 *     time almost always means "the end of the day";
 *   - it supports `disabled` (min/max day or a function), which the
 *     original did not have.
 *
 * See specs/13-sistema-diseno.md#selector-de-fecha for the rest of the
 * docs (why it was chosen, what it does NOT include and how to move a new
 * date field to this component).
 */

import * as React from "react"
import { format } from "date-fns"
import { enUS } from "date-fns/locale"
import * as chrono from "chrono-node"
import { CalendarIcon } from "lucide-react"
import type { Matcher } from "react-day-picker"

import { cn } from "cn"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Calendar } from "@/components/ui/calendar"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"

const COPY = {
  placeholder: "Try 'tomorrow at 9' or 'in 2 weeks'",
  hint: "Press Enter to confirm",
  pickDate: "Pick a date",
}

export interface DatePickerProps {
  /** Id of the trigger (and base for the id of the inner text field,
   * `${id}-search`, so tests can find it without depending on its
   * placeholder). Needed to link a `<Label htmlFor>`. */
  id?: string
  /** Selected date. `undefined` = no date. */
  value?: Date
  onChange?: (date: Date | undefined) => void
  /** date-fns format for the trigger text. @default "MMM d, yyyy · HH:mm" */
  displayFormat?: string
  placeholder?: string
  /** Day(s) that cannot be picked — see react-day-picker's `Matcher` (e.g. `{ before: new Date() }`). */
  disabled?: Matcher | Matcher[]
  className?: string
  "aria-label"?: string
}

/**
 * When a day is picked in the calendar, keep the time already in
 * `previous` (or 23:59 if there was no previous date) — clicking a day
 * should not erase the time the user already typed.
 */
function withPreservedTime(day: Date, previous: Date | undefined): Date {
  const next = new Date(day)
  if (previous) {
    next.setHours(previous.getHours(), previous.getMinutes(), 0, 0)
  } else {
    next.setHours(23, 59, 0, 0)
  }
  return next
}

export function DatePicker({
  id,
  value,
  onChange,
  displayFormat = "MMM d, yyyy · HH:mm",
  placeholder,
  disabled,
  className,
  "aria-label": ariaLabel,
}: DatePickerProps) {
  const [internalDate, setInternalDate] = React.useState<Date>()
  const [inputValue, setInputValue] = React.useState("")
  const [calendarMonth, setCalendarMonth] = React.useState<Date>(value ?? new Date())
  const [isError, setIsError] = React.useState(false)
  const [open, setOpen] = React.useState(false)

  const date = value ?? internalDate
  const setDate = onChange ?? setInternalDate

  function commitInputValue() {
    if (!inputValue.trim()) return
    const parsed = chrono.parseDate(inputValue)
    if (parsed) {
      setDate(parsed)
      setCalendarMonth(parsed)
      setInputValue("")
      setIsError(false)
      setOpen(false)
    } else {
      setIsError(true)
      setTimeout(() => setIsError(false), 350)
    }
  }

  function handleSelect(day: Date | undefined) {
    const next = day ? withPreservedTime(day, date) : undefined
    setDate(next)
    if (next) setCalendarMonth(next)
    setOpen(false)
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger
        render={
          <Button
            id={id}
            type="button"
            variant="outline"
            aria-label={ariaLabel}
            className={cn(
              "w-full justify-start gap-2 font-normal",
              !date && "text-muted-foreground",
              className
            )}
          />
        }
      >
        <CalendarIcon className="size-4 shrink-0" />
        {date ? format(date, displayFormat, { locale: enUS }) : COPY.pickDate}
      </PopoverTrigger>
      <PopoverContent align="start" className="w-auto">
        <Input
          id={id ? `${id}-search` : undefined}
          placeholder={placeholder ?? COPY.placeholder}
          value={inputValue}
          onChange={(e) => {
            setInputValue(e.target.value)
            if (isError) setIsError(false)
          }}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault()
              commitInputValue()
            }
          }}
          className={cn("w-64", isError && "animate-date-picker-shake border-destructive")}
        />
        <p className="px-0.5 text-sm text-muted-foreground">{COPY.hint}</p>
        <Calendar
          mode="single"
          selected={date}
          onSelect={handleSelect}
          month={calendarMonth}
          onMonthChange={setCalendarMonth}
          disabled={disabled}
          locale={enUS}
        />
      </PopoverContent>
    </Popover>
  )
}
