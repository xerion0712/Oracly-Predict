import BasePanel from "./Base"



const TestPanel = ({ visible, close }) => {

    return (
        <BasePanel
            title="Test Panel"
            visible={visible}
            close={close}
        >
            TestPanel here...
        </BasePanel>
    )
}

export default TestPanel