import Head from 'next/head';
import dynamic from 'next/dynamic'

const PrivacyPolicyPage = () => {
    return (
        <div>
            <Head>
                <title>Legato | Privacy Policy</title>
            </Head>
            <section className="dark: relative py-12 lg:py-24 min-h-[90vh]  bg-[url(/assets/images/modern-saas/banner-bg.png)] bg-cover bg-center bg-no-repeat">
                <div className="container pt-6 lg:pt-4  mb-[40px]">

                    <div className="heading mb-0 text-center lg:text-left ">
                        <h6 className="inline-block bg-secondary/10 px-2.5 py-2 !text-secondary">privacy</h6>
                        <h4 className="!font-black uppercase">
                            Privacy <span className="text-secondary">Policy</span>
                        </h4>
                    </div>
                    <p className="mt-2.5 text-center text-lg font-medium lg:text-left ">
                        Last Revised - February 24, 2025
                    </p>

                    <div className='mt-[40px] text-white/80 font-semibold space-y-2'>

                        <div className=' '>
                            Legato, operated by Tamago Blockchain Labs Co., Ltd. (“Tamago”), provides a marketplace for users to create, participate in, and manage AI-powered prediction markets. When you use our services, we collect, use, and store your information when you access Legato (the “Platform”).
                            This Privacy Policy (the “Policy”) explains how Tamago collects, uses, and protects your information, as well as your rights and choices regarding your data.
                        </div>
                        <h2 className='text-xl font-semibold my-4'>1. What This Policy Covers</h2>
                        <p>
                            This Privacy Policy applies to your use of services (including related services, applications, tools, etc., the “Services”) provided to you by Tamago, its affiliates, its licensors, or other providers that have adopted this Policy, as described in our Terms of Service. Please be aware that for certain services, Tamago may provide you the privacy statements in addition to, or in place of, this Privacy Policy, as appropriate.
                        </p>
                        <p>Please only use the Services after you have carefully read and understood this Policy, the Terms of Service. In using the Services, you represent that you understand the contents of this Policy describing our collection, use, transfer and retention of your information herein.</p>
                        <p>If you have any questions or inquiries regarding this Policy, please contact support@tamagolabs.com</p>
                        <h2 className='text-xl font-semibold my-4'>2. The Information We Collect</h2>
                        <p>In this Privacy Policy, “personal information” means any personal information about you which could identify you (by itself or in combination with other data) such as your name, address, email address, wallet address or an online identifies, such as a unique ID, or your internet Protocol (or “IP”) address.</p>
                        <p>We collect personal information about you in a number of different ways. In this section, we explain the different ways we collect personal information about you and the ways in which that information will be used. We will usually collect and store the following data about you when you access and use our Services:</p>
                        <p>2.1 Data You Give Us Directly</p>
                        <li>if you create an account on the Website, we may collect you username, email address, wallet address, personal website URL, messaging applications (e.g., Telegram, Discord, etc.), social media accounts, and other registration-related information;</li>
                        <li>if you execute any activity through the Website, we may collect the transaction information;</li>
                        <li>if you sign up for the Website, our newsletter, content offers, or specific mailing lists, we will collect your email address;</li>
                        <li>if you contact us via our website or through email, raise a complaint, ask for technical support or report a problem with the Website, we will also collect information you provide to use (including your name and email address, as well as any content included in your message);</li>
                        <p>2.2 Data We Collect When You Use Our Services</p>
                        <li>public data or information accessible on the blockchain for any activity made through the Website the IP address used to connect your mobile device or computer to the internet;</li>
                        <li>data about your location, device type and model, operating system and version and platform, and any apps you are using in conjunction with the Website;</li>
                        <li>the number of times you visit or use the Website and the amount of time you spend using it;</li>
                        <p>2.3 Data We Collect From Third-Party Companies</p>
                        <li>data from companies that offer their products or services for use in conjunction with our Services or whose products or services may be linked from our Services (e.g., information shared to third-party wallet providers or payment processors);</li>
                        <li>analytics information provided by third party analytics services engaged to analyze how users use the Services;</li>
                        <li>additional information as may be required from us to comply with legal obligations;</li>
                        <p>Any data obtained through any of the above means may then be associated with other data you have previously provided to us. We will sometimes use third party advertising companies to help us collect this personal information.</p>
                        <h2 className='text-xl font-semibold my-4'>3. Use, Legal Basis of Use and Retention of Your Information</h2>
                        <p>We use your personal information for purposes which are ancillary to the provision of the Website, to conduct research and development, to respond to user inquiries, and to prevent and mitigate fraudulent or illegal activities and for the following ways:</p>
                        <li>to detect and prevent fraud, hacking and/or other cyber-attacks;</li>
                        <li>to keep the Website secure;</li>
                        <li>to improve the Website, for analysis and reporting purposes;</li>
                        <li>to understand your preferences and personalize your experience on the Website;</li>
                        <li>to detect and prevent fraud, hacking and/or other cyber-attacks;</li>
                        <li>to detect and prevent any other harmful or unlawful activity;</li>
                        <li>to comply, with applicable laws and regulations and other requests by competent authorities;</li>
                        <li>act in any other way that we way describe when you provide your Personal information;</li>
                        <h2 className='text-xl font-semibold my-4'>4. What Personal Information Is Shared With or Accessed by Third Parties?</h2>
                        <p>Tamago will share your personal information with various third parties as follows:</p>
                        <li>We use third parties to help us manage your information and the Website, such as our IT service providers, cloud service providers and customer service software and support ticketing providers. These are companies who are authorized to process data on our behalf only as necessary to provide the relevant services to us and cannot use it for their own independent purposes;</li>
                        <li>We may share your data with third-party wallet providers or payment processors to complete any purchases on the Website. As may be necessary, these third-party payment processors may also ask us to share your data with them to confirm the nature of any payment transaction and to verify your identity and payment details;</li>
                        <li>We share your personal information with companies that assist us with out marketing activities where you have opted-in for such communications; and</li>
                        <li>We or our third-party partners may disclose your personal information where we are required or permitted to do so by law or to protect or enforce our rights or the rights of any third party. We may also share your data with third parties to prevent fraud, abusive or unlawful behavior or to demonstrate our compliance with other terms or laws;</li>
                        <p>Any third parties with whom we share your personal information are limited (by law and by contract) in their ability to use your personal information for any purpose other than to provide services for us. We will always take reasonable steps to ensure that any third parties with whom we share your personal information are subject to privacy and security obligations consistent with this Privacy Policy and applicable laws.</p>
                        <p>We will also disclose your personal information to third parties:</p>
                        <p>where it is in our legitimate interests to do so to run, grow, and develop our business, such as:</p>
                        <li>if we sell or buy any business or assets, we may disclose your personal information to the prospective seller or buyer of such business or assets;</li>
                        <li>if we are under a duty to disclose or share your personal information in order to comply with any legal obligation, any lawful request from government or law enforcement officials and as may be required to meet national security or law enforcement requirements or prevent illegal activity;</li>
                        <li>in order to enforce or apply our Terms of Service or any other agreement or terms of use, to respond to any claims, to protect our rights or the rights of a third party, to protect the safely of any person or to prevent any illegal activity; or</li>
                        <li>to protect the rights, property or safety of Tamago, our staff, our customers or other persons. This may include exchanging personal information with other organizations for the purposes of fraud protection;</li>
                        <p>We may also disclose and use anonymised, aggregated reporting and statistics about users of our website or our goods and services for the purpose of internal reporting or reporting to our group or other third parties, and for our marketing and promotion purposes. None of these anonymised, aggregated reports or statistics will enable our users to be personally identified.</p>
                        <p>Save as expressly detailed above, we will never share, sell or rent any of your personal information to any third party without notifying you and, where necessary, obtaining your consent. If you have given your consent for us to use your personal information in a particular way, but later change your mind, you should contact us and we will stop doing so.</p>
                        <h2 className='text-xl font-semibold my-4'>5. Changes to this Privacy Policy</h2>
                        <p>From time to time, in order to comply with changes in applicable laws or for legitimate business purposes, we may make changes to this Policy. Any changes we make will be displayed on this page. Please check back from time to time to ensure that you have read the most recent version of this Policy.</p>
                        <h2 className='text-xl font-semibold my-4'>6. Contacting Tamago</h2>
                        <p>If you have any questions or concern regarding to contents of this Policy or other aspects of how your personal information is handled, please email us at support@tamagolabs.com</p>
                        <p>Once you contact us, we will respond without undue delay to you. Please note when contacting us, we may ask you for certain information in order to verify your identity and respond to your request appropriately.</p>

                    </div>


                </div>
            </section>
        </div>
    )
}

export default PrivacyPolicyPage