package com.example.scooter_android_demo.baseble.exception;

import com.example.scooter_android_demo.baseble.common.BleExceptionCode;

/**
 * @Description: 初始化异常
 * @author: <a href="http://www.xiaoyaoyou1212.com">DAWI</a>
 * @date: 16/8/14 10:30.
 */
public class InitiatedException extends BleException {
    public InitiatedException() {
        super(BleExceptionCode.INITIATED_ERR, "Initiated Exception Occurred! ");
    }
}
