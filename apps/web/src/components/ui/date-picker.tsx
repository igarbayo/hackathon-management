"use client"

/**
 * DatePicker — selector de fecha (y hora) reutilizable para toda la app.
 *
 * Adaptado de "a good date picker" de Guli Moreno
 * (https://github.com/gulipad/a-good-date-picker, MIT License,
 * Copyright (c) 2025 Guli Moreno): un campo de texto en lenguaje natural
 * (chrono-node) con un calendario (react-day-picker) como alternativa,
 * dentro de un Popover. El componente de origen no admite props (estado
 * interno fijo, sin `value`/`onChange`) ni español; se han portado a mano
 * los cambios de la PR #2 del propio repo
 * (https://github.com/gulipad/a-good-date-picker/pull/2: props
 * controladas + `locale`), y además:
 *   - se usan los primitivos de este repo (Button, Input, Popover,
 *     Calendar ya restilados al sistema de diseño F0, ver
 *     specs/13-sistema-diseno.md) en vez de los del repo original;
 *   - al elegir solo el día en el calendario se conserva la hora ya
 *     fijada (o 23:59 si no había ninguna), porque en Hackboard una fecha
 *     sin hora es casi siempre "el final del día";
 *   - admite `disabled` (día mínimo/máximo o una función), que el
 *     original no tenía.
 *
 * Ver specs/13-sistema-diseno.md#selector-de-fecha para el resto de la
 * documentación (por qué se eligió, qué NO trae y cómo migrar un nuevo
 * campo de fecha a este componente).
 */

import * as React from "react"
import { format } from "date-fns"
import { es, enUS } from "date-fns/locale"
import * as chrono from "chrono-node"
import * as chronoEs from "chrono-node/es"
import { CalendarIcon } from "lucide-react"
import type { Matcher } from "react-day-picker"

import { cn } from "cn"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Calendar } from "@/components/ui/calendar"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"

export type DatePickerLocale = "es" | "en"

const LOCALE_COPY: Record<
  DatePickerLocale,
  { placeholder: string; hint: string; pickDate: string; dateFnsLocale: typeof es }
> = {
  es: {
    placeholder: "Prueba «mañana a las 9» o «en 2 semanas»",
    hint: "Pulsa Enter para confirmar",
    pickDate: "Elige una fecha",
    dateFnsLocale: es,
  },
  en: {
    placeholder: "Try 'tomorrow at 9' or 'in 2 weeks'",
    hint: "Press Enter to confirm",
    pickDate: "Pick a date",
    dateFnsLocale: enUS,
  },
}

export interface DatePickerProps {
  /** Id del disparador (y base para el id del campo de texto interno,
   * `${id}-search`, para que los tests puedan encontrarlo sin depender del
   * idioma). Necesario para asociar un `<Label htmlFor>`. */
  id?: string
  /** Fecha seleccionada. `undefined` = sin fecha. */
  value?: Date
  onChange?: (date: Date | undefined) => void
  /** @default "es" */
  locale?: DatePickerLocale
  /** Formato de date-fns para el texto del disparador. @default "d MMM yyyy · HH:mm" */
  displayFormat?: string
  placeholder?: string
  /** Día(s) no seleccionables — ver `Matcher` de react-day-picker (p. ej. `{ before: new Date() }`). */
  disabled?: Matcher | Matcher[]
  className?: string
  "aria-label"?: string
}

/**
 * Cuando se elige un día en el calendario, conserva la hora que ya
 * hubiera en `previous` (o 23:59 si no había fecha previa) — clicar un día
 * no debería borrar la hora que el usuario ya había escrito.
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
  locale = "es",
  displayFormat = "d MMM yyyy · HH:mm",
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
  const copy = LOCALE_COPY[locale]
  const chronoParser = locale === "es" ? chronoEs : chrono

  function commitInputValue() {
    if (!inputValue.trim()) return
    const parsed = chronoParser.parseDate(inputValue)
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
        {date ? format(date, displayFormat, { locale: copy.dateFnsLocale }) : copy.pickDate}
      </PopoverTrigger>
      <PopoverContent align="start" className="w-auto">
        <Input
          id={id ? `${id}-search` : undefined}
          placeholder={placeholder ?? copy.placeholder}
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
        <p className="px-0.5 text-sm text-muted-foreground">{copy.hint}</p>
        <Calendar
          mode="single"
          selected={date}
          onSelect={handleSelect}
          month={calendarMonth}
          onMonthChange={setCalendarMonth}
          disabled={disabled}
          locale={copy.dateFnsLocale}
        />
      </PopoverContent>
    </Popover>
  )
}
