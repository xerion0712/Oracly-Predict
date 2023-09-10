
// import { useState , Fragment } from "react"
// import Image from 'next/image'
// import Jumbotron from '@/components/Jumbotron';
// import Footer from "@/components/Footer" 
// import Floor from '@/components/Floor';
// import Header from '@/components/Header';
// import Link from 'next/link';
// import About from '@/components/About';
// import HowItWorks from '@/components/HowItWorks';
// import { X } from "react-feather"

import Stake from "../components/Stake"

import MainLayout from '@/layouts/mainLayout';

export default function Home() {

  return (
    <MainLayout>
      <Stake/>
    </MainLayout>
  )
}
