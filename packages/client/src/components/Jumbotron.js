import { useRef } from 'react'
import { Canvas, useFrame, useThree } from '@react-three/fiber'
import { WaveMaterial } from "../hooks/WaveMaterial"
import { easing } from 'maath'

function ShaderPlane() {
  const ref = useRef()
  const { viewport, size } = useThree()
  useFrame((state, delta) => {
    ref.current.time += delta

    // ref.current.pointer.x = 0.8
    // ref.current.pointer.y = -0.7
    // state.pointer.x = 0.8
    // state.pointer.y = -0.7

    easing.damp3(ref.current.pointer, state.pointer, 0.2, delta)
  })
  return (
    <mesh scale={[viewport.width, viewport.height, 1]}>
      <planeGeometry />
      <waveMaterial ref={ref} key={WaveMaterial.key} resolution={[size.width * viewport.dpr, size.height * viewport.dpr]} />
    </mesh>
  )
}

export default function Jumbotron() {
  return (
    <Canvas style={{ margin: 0, padding: 0, width: "100%", height: "100%" }}>
      <ShaderPlane />
    </Canvas>
  )
}