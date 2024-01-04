
const Footer = () => {
    return (
        <footer class="bg-transparent rounded-lg shadow mt-4 ">
            <div class="w-full p-2 sm:p-4 flex md:items-center md:justify-between">
                <div class="text-xs mt-1 sm:text-sm mr-2 ">
                    © 2024 Legato
                </div>
                <ul class="flex flex-wrap items-center mt-1 text-xs sm:text-sm sm:mt-0">
                    <li>
                        <a href="https://docs.legato.finance" target="_blank" class="mr-2 sm:mr-4 hover:underline md:mr-6 ">About</a>
                    </li>
                    <li>
                        <a href="https://docs.legato.finance/privacy-policy" target="_blank" class="mr-2 sm:mr-4 hover:underline md:mr-6">Privacy Policy</a>
                    </li>
                    <li>
                        <a href="https://docs.legato.finance/term-of-service" target="_blank" class="mr-2 sm:mr-4 hover:underline md:mr-6">Term of Service</a>
                    </li>
                </ul>
            </div>
        </footer>
    )
}

export default Footer