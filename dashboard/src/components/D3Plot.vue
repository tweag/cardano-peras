<script setup lang="ts">
import { defineProps, onMounted, onUnmounted, ref, watch, nextTick } from 'vue'
import * as d3 from 'd3'

export interface Axis {
  label: string
  log?: boolean
  scientific?: boolean
}

export interface DataPoint {
  x: number
  y: number
}

export interface Curve {
  label: string
  data: DataPoint[]
}

const props = defineProps<{
  axes: { x: Axis; y: Axis }
  curves: Curve[]
  palette?: string[]
  margin?: number
}>()

const plot = ref(null)

const primaryColor = getComputedStyle(document.documentElement)
  .getPropertyValue('--pico-color')
  .trim()

const render = async () => {
  if (!plot.value) return
  await nextTick()

  // Initialize plot parameters
  const margin = props.margin ?? 100
  const vMargin = margin / 2
  const width = plot.value.clientWidth
  const height = plot.value.clientHeight
  const palette = props.palette ?? d3.schemeCategory10

  // Clear previous contents
  d3.select(plot.value).selectAll('*').remove()

  // Create SVG element
  const svgElem = d3
    .select(plot.value)
    .append('svg')
    .attr('width', width)
    .attr('height', height)

  // Draw curves
  const allPoints = props.curves.flatMap((curve) => curve.data)
  const xMin = d3.min(allPoints, (d) => d.x)
  const yMin = d3.min(allPoints, (d) => d.y)
  const xMax = d3.max(allPoints, (d) => d.x)
  const yMax = d3.max(allPoints, (d) => d.y)

  const curves = svgElem.append('g').attr('class', 'curves')

  const xScale = props.axes.x.log ? d3.scaleLog() : d3.scaleLinear()
  xScale.domain([xMin, xMax]).range([margin, width - margin])

  const xAxis = props.axes.x.scientific
    ? d3.axisBottom(xScale).ticks(10, 'e')
    : d3.axisBottom(xScale)

  curves
    .append('g')
    .attr('transform', `translate(0, ${height - vMargin})`)
    .call(xAxis)
    .append('text')
    .attr('x', width / 2)
    .attr('y', margin / 2)
    .attr('fill', primaryColor)
    .attr('text-anchor', 'middle')
    .text(props.axes.x.label)

  const yScale = props.axes.y.log ? d3.scaleLog() : d3.scaleLinear()
  yScale.domain([yMin, yMax]).range([height - vMargin, vMargin])

  const yAxis = props.axes.y.scientific
    ? d3.axisLeft(yScale).ticks(10, 'e')
    : d3.axisLeft(yScale)

  curves
    .append('g')
    .attr('transform', `translate(${margin}, 0)`)
    .call(yAxis)
    .append('text')
    .attr('transform', 'rotate(-90)')
    .attr('x', -height / 2)
    .attr('y', -margin / 2)
    .attr('fill', primaryColor)
    .attr('text-anchor', 'middle')
    .text(props.axes.y.label)

  // Draw data
  const toLine = d3
    .line<DataPoint>()
    .x((d) => xScale(d.x))
    .y((d) => yScale(d.y))

  const lines = svgElem.append('g').attr('class', 'lines')

  lines
    .selectAll('path.line')
    .data(props.curves)
    .join('path')
    .attr('class', 'line')
    .attr('d', (curve) => toLine(curve.data))
    .attr('fill', 'none')
    .attr('stroke', (_, idx) => palette[idx % palette.length])
    .attr('stroke-width', 2)

  // Draw legends
  const legends = svgElem.append('g').attr('class', 'legends')
  legends
    .selectAll('rect.legend')
    .data(props.curves)
    .join('rect')
    .attr('class', 'legend')
    .attr('x', margin + 10)
    .attr('y', (_, idx) => height - (vMargin + idx * 25) - 30)
    .attr('width', 20)
    .attr('height', 20)
    .attr('fill', (_, idx) => palette[idx % palette.length])
  legends
    .selectAll('text.legend-label')
    .data(props.curves)
    .join('text')
    .attr('class', 'legend-label')
    .attr('x', margin + 40)
    .attr('y', (_, idx) => height - (vMargin + idx * 25) - 15)
    .text((axis) => axis.label)
}

// Initial render and watch for data changes
onMounted(() => {
  if (!plot.value) return
  const observer = new ResizeObserver(() => render())
  observer.observe(plot.value)
  onUnmounted(() => observer.disconnect())
})
watch(() => props.curves, render)
</script>

<template>
  <div ref="plot" class="plot"></div>
</template>

<style scoped>
.plot {
  /* TODO: revisit this */
  width: 100%;
  height: 500px;
}
</style>
