import Link from 'next/link';

const Footer = () => {
    return (
        <footer className="mt-auto bg-white dark:bg-transparent dark:bg-gradient-to-b dark:from-white/[0.03] dark:to-transparent">
            <div className="bg-gradient-to-r from-[#FCF1F4] to-[#EDFBF9] py-5 dark:border-t-2 dark:border-white/5 dark:bg-none">
                <div className="container">
                    <div className="items-center justify-between  font-bold dark:text-white flex">
                        <div className='text-sm '>
                            <span className='hidden md:inline-flex'>Copyright</span>© {new Date().getFullYear() + ' '}
                            <Link href="https://legato.finance" className="text-secondary transition hover:text-secondary">
                                Legato
                            </Link>
                        </div>
                        <div className='flex flex-row  justify-center  '>
                            <div className="text-sm px-2">
                                <Link href="/privacy-policy" className="text-white transition hover:text-secondary">
                                    Privacy Policy
                                </Link>
                            </div>
                            <div className="text-sm px-2">
                                <Link href="/terms-of-service" className="text-white transition hover:text-secondary">
                                    Terms of Service
                                </Link>
                            </div>
                        </div> 
                    </div>
                </div>
            </div>
        </footer>
    );
};

export default Footer;
