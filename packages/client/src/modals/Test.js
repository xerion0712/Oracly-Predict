import BaseModal from "./Base"



const TestModal = ({ visible, close }) => {

    return (
        <BaseModal
            title="Test"
            visible={visible}
            close={close}
        >
            TestModal here...
        </BaseModal>
    )
}

export default TestModal