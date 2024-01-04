import { Listbox, Transition } from '@headlessui/react'
import { Fragment, useState, useEffect, useCallback } from 'react'
import { CheckIcon, ChevronUpDownIcon, ChevronDownIcon, ArrowRightIcon } from "@heroicons/react/20/solid"

function classNames(...classes) {
    return classes.filter(Boolean).join(' ')
}

const Selector = ({
    name,
    selected,
    setSelected,
    options
}) => {
    return (
        <Listbox value={selected} onChange={setSelected}>
            {({ open }) => (
                <>
                    <Listbox.Label className="block mt-6 text-sm font-medium leading-6 text-gray-300">{name}</Listbox.Label>
                    <div className="relative mt-2">
                        <Listbox.Button className="relative hover:cursor-pointer w-full cursor-default rounded-md  py-3 pl-3 pr-10 text-left  shadow-sm sm:text-sm sm:leading-6  bg-gray-700 placeholder-gray-400 text-white   ">
                            <span className="flex items-center">
                                <span className="mr-3 block truncate">{selected && selected.name}</span>
                                <img src={selected && selected.image} alt="" className="h-5 w-5 ml-auto flex-shrink-0 rounded-full" />
                                <span className="ml-2 block font-medium w-[32px] text-right">
                                    {selected && selected.value}
                                </span>
                            </span>
                            <span className="pointer-events-none absolute inset-y-0 right-0 ml-3 flex items-center pr-2">
                                <ChevronUpDownIcon className="h-5 w-5 text-gray-400" aria-hidden="true" />
                            </span>
                        </Listbox.Button>
                        <Transition
                            show={open}
                            as={Fragment}
                            leave="transition ease-in duration-100"
                            leaveFrom="opacity-100"
                            leaveTo="opacity-0"
                        >
                            <Listbox.Options className="absolute z-10 mt-1 max-h-56 w-full overflow-auto rounded-md bg-gray-700 placeholder-gray-400 text-white py-2 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm">
                                {options.map((item) => (
                                    <Listbox.Option
                                        key={item.id}
                                        className={({ active }) =>
                                            classNames(
                                                active ? 'bg-blue-600 text-white' : 'text-gray-900',
                                                'relative cursor-pointer select-none py-2 pl-3 pr-9'
                                            )
                                        }
                                        value={item}
                                    >
                                        {({ selected, active }) => (
                                            <>
                                                <div className="flex items-center">
                                                    <span
                                                        className={classNames(selected ? 'font-semibold' : 'font-normal', 'ml-3 block text-white truncate')}
                                                    >
                                                        {item.name}
                                                    </span>
                                                    <img src={item.image} alt="" className="h-5 w-5 ml-auto flex-shrink-0 rounded-full" />
                                                    <span className="ml-2 block text-white font-medium w-[25px] text-right">
                                                        {item.value}
                                                    </span>
                                                </div>
                                            </>
                                        )}
                                    </Listbox.Option>
                                ))}
                            </Listbox.Options>
                        </Transition>
                    </div>
                </>
            )}
        </Listbox>
    )
}

export const FixedSelector = ({ name, selected, select }) => {
    return (
        <>
            <Listbox>
                <Listbox.Label className="block mt-6 text-sm font-medium leading-6 text-gray-300">{name}</Listbox.Label>
                <div className="relative mt-2">
                    <Listbox.Button onClick={select} className="relative hover:cursor-pointer w-full cursor-default rounded-md  py-3 pl-3 pr-10 text-left  shadow-sm sm:text-sm sm:leading-6  bg-gray-700 placeholder-gray-400 text-white   ">
                        <span className="flex items-center">
                            <span className="mr-3 block truncate">{selected && selected.name}</span>
                            <img src={selected && selected.image} alt="" className="h-5 w-5 ml-auto flex-shrink-0 rounded-full" />
                            <span className="ml-2 block font-medium w-[32px] text-right">
                                {selected && selected.value}
                            </span>
                        </span>
                        <span className="pointer-events-none absolute inset-y-0 right-0 ml-3 flex items-center pr-2">
                            <ChevronUpDownIcon className="h-5 w-5 text-gray-400" aria-hidden="true" />
                        </span>
                    </Listbox.Button>
                </div>
            </Listbox>

        </>
    )
}

export default Selector