
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



      <footer class="bg-transparent rounded-lg shadow mt-4 ">
        <div class="w-full mx-auto max-w-screen-xl p-4 md:flex md:items-center md:justify-between">
          <span class="text-sm">© 2023 Legato Finance
          </span>
          <span class=" text-sm   ">
            Made with ❤️ during Move Hackathon by WebX
          </span>
          {/* <ul class="flex flex-wrap items-center mt-3 text-sm font-medium text-gray-500 dark:text-gray-400 sm:mt-0">
            <li>
              <a href="#" class="mr-4 hover:underline md:mr-6 ">About</a>
            </li>
            <li>
              <a href="#" class="mr-4 hover:underline md:mr-6">Privacy Policy</a>
            </li>
            <li>
              <a href="#" class="mr-4 hover:underline md:mr-6">Licensing</a>
            </li>
            <li>
              <a href="#" class="hover:underline">Contact</a>
            </li>
          </ul> */}
        </div>
      </footer>




    </main>
  )
}
