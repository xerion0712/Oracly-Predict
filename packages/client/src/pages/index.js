
import Image from 'next/image'
import FullLayout from "@/layouts/fullLayout";
import Jumbotron from '@/components/Jumbotron';

import { Canvas } from "@react-three/fiber";
// import css from "../styles/Home.module.css"
import Floor from '@/components/Floor';
import MainLayout from '@/layouts/mainLayout';
import Header from '@/components/Header';

export default function Home() {
  return (
    <main className='min-h-screen bg-black text-white'>

      <div className='h-screen bg-white relative'> 
        <Jumbotron />
        <div className="absolute top-0 h-30 w-full z-100">
          <div className="mx-auto container">
            <Header />
          </div>
        </div>
        <div className="absolute font-mono top-40 w-full z-100 pointer-events-none">
          <section>
            <div className="container mx-auto flex flex-col items-center py-16 text-center max-w-4xl">
              <div className='bg-black bg-opacity-10 backdrop-blur-lg   drop-shadow-lg p-16 border-2'>
                <h1 className="text-6xl font-bold leadi">Non-Linear Liquid Staking Protocol
                </h1>
                <p className="px-8 mt-8 mb-12 text-lg">Cupiditate minima voluptate temporibus quia? Architecto beatae esse ab amet vero eaque explicabo!</p>
                <div className="flex flex-wrap justify-center pointer-events-auto">
                  <button className="px-8 py-3 m-2 text-lg font-semibold rounded dark:bg-violet-400 dark:text-gray-900">Get started</button>
                  <button className="px-8 py-3 m-2 text-lg border rounded dark:text-gray-50 dark:border-gray-700">Learn more</button>
                </div>
              </div>

            </div>
          </section>
        </div>
      </div>


      <div class="grid grid-cols-4 gap-3">
        <div class="col-span-1 bg-slate-800 rounded-lg px-6 py-8 ring-1 ring-slate-900/5 shadow-xl">
          <div>
            <span class="inline-flex items-center justify-center p-2 bg-indigo-500 rounded-md shadow-lg">
              <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true"></svg>
            </span>
          </div>
          <h3 class="text-white mt-5 text-base font-medium tracking-tight">Writes Upside-Down</h3>
          <p class="text-slate-400 mt-2 text-sm">
            The Zero Gravity Pen can be used to write in any orientation, including upside-down. It even works in outer space.
          </p>
        </div>
      </div>



    </main>
  )
}
