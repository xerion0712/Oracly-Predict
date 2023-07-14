
import Image from 'next/image'
import Jumbotron from '@/components/Jumbotron';
import Footer from "@/components/Footer"
// import css from "../styles/Home.module.css"
import Floor from '@/components/Floor';
import MainLayout from '@/layouts/mainLayout';
import Header from '@/components/Header';
import Link from 'next/link';

export default function Home() {
  return (
    <main className='min-h-screen bg-black text-white'>
      <div className='h-screen bg-white relative'>
        <Jumbotron />
        <div className="absolute top-0 h-30 w-full z-100">
          <div className="mx-auto container">
            <Header landing={true} />
          </div>
        </div>
        <div className="absolute font-mono top-40 w-full z-100 pointer-events-none">
          <section>
            <div className="container mx-auto flex flex-col items-center py-16 text-center max-w-4xl">
              <div className='bg-black bg-opacity-10 backdrop-blur-lg   drop-shadow-lg p-16 border-2'>
                <h1 className="text-6xl font-bold leadi">Non-Linear Liquid Staking Protocol
                </h1>
                <p className="px-8 mt-8 mb-12 text-lg">Optimize the trading strategy for future yield of any staking assets on Sui blockchain</p>
                <div className="flex flex-wrap justify-center pointer-events-auto">
                  <Link href="/stake">
                    <button className="px-8 py-3 m-2 text-lg font-semibold rounded dark:bg-violet-400 dark:text-gray-900 hover:underline">Launch App</button>
                  </Link> 
                  <button className="px-8 py-3 m-2 text-lg border rounded dark:text-gray-50 dark:border-gray-700">Learn more</button>
                </div>
              </div>

            </div>
          </section>
        </div>
      </div>
      <Footer />
    </main>
  )
}
